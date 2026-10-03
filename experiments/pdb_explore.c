/* Host-only experiment: compare candidate pattern databases for IDA*.
 *
 * For each candidate abstraction it reports the table size, the largest
 * heuristic value, and the IDA* node count (worst and mean) over all 2,644
 * distance-11 states.  Not part of the target build; RV32I constraints do not
 * apply here.
 *
 *   cc -O2 -o pdb_explore experiments/pdb_explore.c && ./pdb_explore
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { N = 7, NP = 5040, NO = 729, STATES = NP * NO };

typedef struct {
    uint8_t p[N], o[N];
} state_t;

static const uint8_t source[3][N] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};
static const uint8_t twist[3][N] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};

static state_t quarter(state_t s, int f)
{
    state_t r;
    for (int i = 0; i < N; i++) {
        r.p[i] = s.p[source[f][i]];
        r.o[i] = (uint8_t) ((s.o[source[f][i]] + twist[f][i]) % 3);
    }
    return r;
}

static uint32_t rank_p(const state_t *s)
{
    uint32_t p = 0;
    for (int i = 0; i < N; i++) {
        int smaller = 0;
        for (int j = i + 1; j < N; j++)
            smaller += s->p[j] < s->p[i];
        p = p * (uint32_t) (N - i) + (uint32_t) smaller;
    }
    return p;
}

static uint32_t rank_o(const state_t *s)
{
    uint32_t o = 0;
    for (int i = 0; i < 6; i++)
        o = o * 3 + s->o[i];
    return o;
}

static void unrank(uint32_t rank, state_t *s)
{
    uint8_t avail[N] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / NO, o = rank % NO, f = 720;
    int sum = 0;
    for (int i = 0; i < N; i++) {
        int q = (int) (p / f);
        p %= f;
        s->p[i] = avail[q];
        for (int j = q; j + 1 < N - i; j++)
            avail[j] = avail[j + 1];
        if (i < 6)
            f /= (uint32_t) (6 - i);
    }
    for (int i = 6; i-- > 0;) {
        s->o[i] = (uint8_t) (o % 3);
        sum += s->o[i];
        o /= 3;
    }
    s->o[6] = (uint8_t) ((3 - sum % 3) % 3);
}

/* ---- full distance table (ground truth) ---- */
static uint16_t pmove[3][NP], omove[3][NO];
static uint8_t *dist;

static void build_truth(void)
{
    state_t s;
    for (uint32_t r = 0; r < NP; r++) {
        unrank(r * NO, &s);
        for (int f = 0; f < 3; f++) {
            state_t t = quarter(s, f);
            pmove[f][r] = (uint16_t) rank_p(&t);
        }
    }
    for (uint32_t r = 0; r < NO; r++) {
        unrank(r, &s);
        for (int f = 0; f < 3; f++) {
            state_t t = quarter(s, f);
            omove[f][r] = (uint16_t) rank_o(&t);
        }
    }
    dist = malloc(STATES);
    uint32_t *q = malloc(STATES * sizeof *q);
    memset(dist, 0xff, STATES);
    uint32_t head = 0, tail = 0;
    dist[0] = 0;
    q[tail++] = 0;
    while (head < tail) {
        uint32_t x = q[head++];
        uint32_t p = x / NO, o = x % NO;
        for (int f = 0; f < 3; f++) {
            uint32_t np = p, no = o;
            for (int t = 0; t < 3; t++) {
                np = pmove[f][np];
                no = omove[f][no];
                uint32_t y = np * NO + no;
                if (dist[y] == 0xff) {
                    dist[y] = (uint8_t) (dist[x] + 1);
                    q[tail++] = y;
                }
            }
        }
    }
    free(q);
}

/* ---- abstractions ----
 * kind 0: perm only                (5040)
 * kind 1: orientation only         (729)
 * kind 2: perm x twist of cubies C (5040 * 3^k)
 * kind 3: orientation x places of cubies C (729 * 7*6*..)
 */
typedef struct {
    const char *name;
    int kind, k;
    uint8_t cub[4];
    uint32_t size;
    uint8_t *pdb;
    int maxh;
} abs_t;

static uint32_t abs_index(const abs_t *a, const state_t *s)
{
    uint8_t where[N];
    for (int i = 0; i < N; i++)
        where[s->p[i]] = (uint8_t) i;
    switch (a->kind) {
    case 0:
        return rank_p(s);
    case 1:
        return rank_o(s);
    case 2: {
        uint32_t v = rank_p(s);
        for (int i = 0; i < a->k; i++)
            v = v * 3 + s->o[where[a->cub[i]]];
        return v;
    }
    default: {
        uint32_t v = rank_o(s);
        for (int i = 0; i < a->k; i++)
            v = v * 7 + where[a->cub[i]];
        return v;
    }
    }
}

static uint32_t abs_size(const abs_t *a)
{
    uint32_t v = a->kind == 0 || a->kind == 2 ? NP : NO;
    for (int i = 0; i < a->k; i++)
        v *= a->kind == 2 ? 3 : 7;
    return v;
}

/* pdb[a] = min over states s with abs(s) == a of dist(s).  Because each
 * abstraction here is a quotient compatible with the moves, this equals the
 * abstract-graph distance and is therefore admissible. */
static void build_pdb(abs_t *a)
{
    state_t s;
    a->size = abs_size(a);
    a->pdb = malloc(a->size);
    memset(a->pdb, 0xff, a->size);
    for (uint32_t r = 0; r < STATES; r++) {
        unrank(r, &s);
        uint32_t i = abs_index(a, &s);
        if (dist[r] < a->pdb[i])
            a->pdb[i] = dist[r];
    }
    a->maxh = 0;
    uint32_t used = 0;
    for (uint32_t i = 0; i < a->size; i++)
        if (a->pdb[i] != 0xff) {
            used++;
            if (a->pdb[i] > a->maxh)
                a->maxh = a->pdb[i];
        }
    a->size = used; /* reachable entries = dense table size */
}

/* ---- IDA* ---- */
static abs_t *hs[4];
static int nh;
static uint64_t nodes;

static int h(const state_t *s)
{
    int best = 0;
    for (int i = 0; i < nh; i++) {
        int v = hs[i]->pdb[abs_index(hs[i], s)];
        if (v > best)
            best = v;
    }
    return best;
}

static int dfs(state_t s, int g, int bound, int last)
{
    nodes++;
    int hv = h(&s);
    if (g + hv > bound)
        return 0;
    if (hv == 0 && rank_p(&s) == 0 && rank_o(&s) == 0)
        return 1;
    for (int f = 0; f < 3; f++) {
        if (f == last)
            continue;
        state_t t = s;
        for (int k = 0; k < 3; k++) {
            t = quarter(t, f);
            if (dfs(t, g + 1, bound, f))
                return 1;
        }
    }
    return 0;
}

static int solve(state_t s)
{
    for (int bound = h(&s);; bound++)
        if (dfs(s, 0, bound, -1))
            return bound;
}

static void evaluate(const char *label)
{
    state_t s;
    uint64_t worst = 0, total = 0, count = 0;
    for (uint32_t r = 0; r < STATES; r++) {
        if (dist[r] != 11)
            continue;
        unrank(r, &s);
        nodes = 0;
        int len = solve(s);
        if (len != 11) {
            printf("  NOT OPTIMAL at rank %u: %d\n", r, len);
            exit(1);
        }
        if (nodes > worst)
            worst = nodes;
        total += nodes;
        count++;
    }
    printf("%-34s worst %8llu  mean %9.0f  (%llu states)\n", label,
           (unsigned long long) worst, (double) total / (double) count,
           (unsigned long long) count);
}

/* Try every 3-cubie subset for max(orient x place{a,b,c}, perm). */
static void sweep_triples(void)
{
    static abs_t perm = {"perm", 0, 0, {0}, 0, 0, 0};
    build_pdb(&perm);
    for (int a = 0; a < N; a++)
        for (int b = a + 1; b < N; b++)
            for (int c = b + 1; c < N; c++) {
                abs_t t = {"", 3, 3, {(uint8_t) a, (uint8_t) b, (uint8_t) c},
                           0, 0, 0};
                build_pdb(&t);
                char label[64];
                snprintf(label, sizeof label, "max(orient x place{%d,%d,%d}, perm)",
                         a, b, c);
                nh = 2; hs[0] = &t; hs[1] = &perm;
                evaluate(label);
                free(t.pdb);
            }
}

int main(int argc, char **argv)
{
    build_truth();
    if (argc > 1 && !strcmp(argv[1], "--triples")) {
        sweep_triples();
        return 0;
    }
    static abs_t cand[] = {
        {"perm", 0, 0, {0}, 0, 0, 0},
        {"orient", 1, 0, {0}, 0, 0, 0},
        {"perm x twist{0,1}", 2, 2, {0, 1}, 0, 0, 0},
        {"perm x twist{0,1,2}", 2, 3, {0, 1, 2}, 0, 0, 0},
        {"perm x twist{0,3,6}", 2, 3, {0, 3, 6}, 0, 0, 0},
        {"orient x place{0,1}", 3, 2, {0, 1}, 0, 0, 0},
        {"orient x place{0,1,2}", 3, 3, {0, 1, 2}, 0, 0, 0},
        {"orient x place{0,3,6}", 3, 3, {0, 3, 6}, 0, 0, 0},
    };
    int nc = (int) (sizeof cand / sizeof cand[0]);
    for (int i = 0; i < nc; i++) {
        build_pdb(&cand[i]);
        printf("%-24s entries %7u  nibble-packed %6u B  max h %d\n",
               cand[i].name, cand[i].size, (cand[i].size + 1) / 2,
               cand[i].maxh);
    }
    puts("");
    nh = 2; hs[0] = &cand[0]; hs[1] = &cand[1];
    evaluate("max(perm, orient)");
    for (int i = 2; i < nc; i++) {
        nh = 1; hs[0] = &cand[i];
        evaluate(cand[i].name);
        nh = 2; hs[1] = cand[i].kind == 2 ? &cand[1] : &cand[0];
        char label[64];
        snprintf(label, sizeof label, "max(%s, %s)", cand[i].name,
                 hs[1]->name);
        evaluate(label);
    }
    return 0;
}
