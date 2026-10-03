/* Host-side table generator for the IDA* solver.
 *
 * Coordinates (all independent, each with its own quarter-turn table):
 *   perm   0..5039  Lehmer rank of p[0..6], same as the baseline
 *   orient 0..728   base-3 value of o[0..5]; o[6] follows from the invariant
 *   place  0..209   positions of cubies 0, 1, 2 (dense rank, see place_rank)
 *
 * Heuristic: h = max(pdb_perm[perm], pdb_ol[place * 729 + orient]).
 * Both pattern databases are exact distances in an abstract graph obtained
 * by forgetting part of the state, so neither can exceed the true distance.
 *
 * Gates checked here: H1 (admissibility over all 3,674,160 states),
 * H2 (tables complete, maxima, solved entries) and H4 (packed accessor).
 * Output: tables.h, included by fast.c.
 *
 *   cc -O2 -o gen_tables gen_tables.c && ./gen_tables tables.h
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum {
    N = 7,
    NP = 5040,
    NO = 729,
    NL = 210,
    STATES = NP * NO,
    NOL = NL * NO,
};

typedef struct {
    uint8_t p[N], o[N];
} state_t;

/* Same move definition as the baseline solver.c. */
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

static uint32_t perm_rank(const uint8_t *p)
{
    uint32_t r = 0;
    for (int i = 0; i < N; i++) {
        uint32_t smaller = 0;
        for (int j = i + 1; j < N; j++)
            smaller += p[j] < p[i];
        r = r * (uint32_t) (N - i) + smaller;
    }
    return r;
}

static void perm_unrank(uint32_t r, uint8_t *p)
{
    uint8_t avail[N] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t f = 720;
    for (int i = 0; i < N; i++) {
        uint32_t q = r / f;
        r %= f;
        p[i] = avail[q];
        for (uint32_t j = q; j + 1 < (uint32_t) (N - i); j++)
            avail[j] = avail[j + 1];
        if (i < 6)
            f /= (uint32_t) (6 - i);
    }
}

static uint32_t orient_rank(const uint8_t *o)
{
    uint32_t r = 0;
    for (int i = 0; i < 6; i++)
        r = r * 3 + o[i];
    return r;
}

static void orient_unrank(uint32_t r, uint8_t *o)
{
    int sum = 0;
    for (int i = 6; i-- > 0;) {
        o[i] = (uint8_t) (r % 3);
        sum += o[i];
        r /= 3;
    }
    o[6] = (uint8_t) ((3 - sum % 3) % 3);
}

/* Positions a, b, c of cubies 0, 1, 2 (pairwise distinct, 0..6) packed into
 * 0..209: a * 30 + b' * 5 + c', where b' and c' skip the taken positions.
 * fast.c computes the same rank once, from the input. */
static uint32_t place_rank(int a, int b, int c)
{
    int bb = b - (b > a);
    int cc = c - (c > a) - (c > b);
    return (uint32_t) (a * 30 + bb * 5 + cc);
}

static uint32_t place_of_perm(const uint8_t *p)
{
    int where[N];
    for (int i = 0; i < N; i++)
        where[p[i]] = i;
    return place_rank(where[0], where[1], where[2]);
}

static uint16_t pm[3][NP], om[3][NO];
static uint8_t lm[3][NL];
static uint8_t pdb_perm[NP], pdb_ol[NOL];

static void build_moves(void)
{
    state_t s;
    memset(&s, 0, sizeof s);
    for (uint32_t r = 0; r < NP; r++) {
        perm_unrank(r, s.p);
        for (int f = 0; f < 3; f++) {
            state_t t = quarter(s, f);
            pm[f][r] = (uint16_t) perm_rank(t.p);
        }
    }
    memset(&s, 0, sizeof s);
    for (int i = 0; i < N; i++)
        s.p[i] = (uint8_t) i;
    for (uint32_t r = 0; r < NO; r++) {
        orient_unrank(r, s.o);
        for (int f = 0; f < 3; f++) {
            state_t t = quarter(s, f);
            om[f][r] = (uint16_t) orient_rank(t.o);
        }
    }
    /* Destination of the cubie at position j after a quarter turn. */
    int dest[3][N];
    for (int f = 0; f < 3; f++)
        for (int i = 0; i < N; i++)
            dest[f][source[f][i]] = i;
    memset(lm, 0xff, sizeof lm);
    for (int a = 0; a < N; a++)
        for (int b = 0; b < N; b++)
            for (int c = 0; c < N; c++) {
                if (a == b || a == c || b == c)
                    continue;
                uint32_t r = place_rank(a, b, c);
                for (int f = 0; f < 3; f++)
                    lm[f][r] = (uint8_t) place_rank(dest[f][a], dest[f][b],
                                                    dest[f][c]);
            }
}

/* Breadth-first search in an abstract graph given by up to two coordinate
 * move tables.  Index = x * nb + y. */
static int bfs(uint8_t *d, uint32_t na, uint32_t nb, const uint16_t *ma,
               const uint8_t *ma8, const uint16_t *mb)
{
    uint32_t n = na * nb;
    uint32_t *q = malloc(n * sizeof *q);
    uint32_t head = 0, tail = 0;
    memset(d, 0xff, n);
    d[0] = 0;
    q[tail++] = 0;
    while (head < tail) {
        uint32_t x = q[head++];
        uint32_t a = x / nb, b = x % nb;
        for (int f = 0; f < 3; f++) {
            uint32_t na2 = a, nb2 = b;
            for (int t = 0; t < 3; t++) {
                na2 = ma ? ma[f * na + na2] : ma8[f * na + na2];
                nb2 = mb ? mb[f * nb + nb2] : 0;
                uint32_t y = na2 * nb + nb2;
                if (d[y] == 0xff) {
                    d[y] = (uint8_t) (d[x] + 1);
                    q[tail++] = y;
                }
            }
        }
    }
    free(q);
    return tail == n;
}

static int max_of(const uint8_t *d, uint32_t n)
{
    int m = 0;
    for (uint32_t i = 0; i < n; i++)
        if (d[i] > m)
            m = d[i];
    return m;
}

static void pack(const uint8_t *src, uint32_t n, uint8_t *dst)
{
    for (uint32_t i = 0; i < n; i += 2)
        dst[i >> 1] = (uint8_t) (src[i] | (i + 1 < n ? src[i + 1] << 4 : 0));
}

/* The accessor fast.c uses, duplicated here for gate H4. */
static int nibble(const uint8_t *t, uint32_t i)
{
    uint8_t byte = t[i >> 1];
    return (i & 1) ? byte >> 4 : byte & 15;
}

#define FAIL(...)                         \
    do {                                  \
        fprintf(stderr, "FAIL: " __VA_ARGS__); \
        exit(1);                          \
    } while (0)

static void emit_u8(FILE *f, const char *name, const uint8_t *v, uint32_t n)
{
    fprintf(f, "static const uint8_t %s[%u] = {", name, n);
    for (uint32_t i = 0; i < n; i++)
        fprintf(f, "%s%u,", i % 20 ? "" : "\n    ", v[i]);
    fprintf(f, "\n};\n\n");
}

static void emit_u16(FILE *f, const char *name, const uint16_t *v, uint32_t n)
{
    fprintf(f, "static const uint16_t %s[%u] = {", name, n);
    for (uint32_t i = 0; i < n; i++)
        fprintf(f, "%s%u,", i % 14 ? "" : "\n    ", v[i]);
    fprintf(f, "\n};\n\n");
}

static void emit_u32(FILE *f, const char *name, const uint32_t *v, uint32_t n)
{
    fprintf(f, "static const uint32_t %s[%u] = {", name, n);
    for (uint32_t i = 0; i < n; i++)
        fprintf(f, "%s%u,", i % 10 ? "" : "\n    ", v[i]);
    fprintf(f, "\n};\n\n");
}

int main(int argc, char **argv)
{
    const char *out = argc > 1 ? argv[1] : "tables.h";
    build_moves();

    /* Consistency: the place coordinate must follow the permutation. */
    {
        uint8_t p[N];
        for (uint32_t r = 0; r < NP; r++) {
            perm_unrank(r, p);
            uint32_t l = place_of_perm(p);
            for (int f = 0; f < 3; f++) {
                uint8_t q[N];
                perm_unrank(pm[f][r], q);
                if (place_of_perm(q) != lm[f][l])
                    FAIL("place table disagrees with perm table at %u\n", r);
            }
        }
    }

    /* Pattern databases. */
    if (!bfs(pdb_perm, NP, 1, &pm[0][0], NULL, NULL))
        FAIL("perm PDB incomplete\n");
    if (!bfs(pdb_ol, NL, NO, NULL, &lm[0][0], &om[0][0]))
        FAIL("orient x place PDB incomplete\n");

    /* H2: complete, bounded, solved entries are zero. */
    int max_p = max_of(pdb_perm, NP), max_ol = max_of(pdb_ol, NOL);
    if (max_p > 15 || max_ol > 15)
        FAIL("PDB value does not fit in a nibble\n");
    if (pdb_perm[0] != 0 || pdb_ol[0] != 0)
        FAIL("solved entry is not zero\n");
    printf("H2 ok: pdb_perm %u entries max %d, pdb_ol %u entries max %d\n",
           NP, max_p, NOL, max_ol);

    /* Packed copies and H4. */
    static uint8_t packed_perm[(NP + 1) / 2], packed_ol[(NOL + 1) / 2];
    pack(pdb_perm, NP, packed_perm);
    pack(pdb_ol, NOL, packed_ol);
    for (uint32_t i = 0; i < NP; i++)
        if (nibble(packed_perm, i) != pdb_perm[i])
            FAIL("H4 perm accessor at %u\n", i);
    for (uint32_t i = 0; i < NOL; i++)
        if (nibble(packed_ol, i) != pdb_ol[i])
            FAIL("H4 ol accessor at %u\n", i);
    printf("H4 ok: packed accessor matches at all even and odd indices\n");

    /* H1: admissibility against the exact distance of every state. */
    {
        uint8_t *dist = malloc(STATES);
        if (!bfs(dist, NP, NO, &pm[0][0], NULL, &om[0][0]))
            FAIL("full BFS incomplete\n");
        static uint16_t place_perm[NP];
        uint8_t p[N];
        for (uint32_t r = 0; r < NP; r++) {
            perm_unrank(r, p);
            place_perm[r] = (uint16_t) place_of_perm(p);
        }
        uint32_t exact = 0;
        uint64_t sum_gap = 0;
        for (uint32_t s = 0; s < STATES; s++) {
            uint32_t pr = s / NO, orr = s % NO;
            int a = pdb_perm[pr];
            int b = pdb_ol[place_perm[pr] * NO + orr];
            int h = a > b ? a : b;
            if (h > dist[s])
                FAIL("H1: h=%d > d=%d at state %u\n", h, dist[s], s);
            if (h == 0 && s != 0)
                FAIL("H1: h=0 at unsolved state %u\n", s);
            exact += h == dist[s];
            sum_gap += (uint64_t) (dist[s] - h);
        }
        printf("H1 ok: h <= d for all %u states (h == d for %u, mean gap %.3f)"
               ", diameter %d\n",
               STATES, exact, (double) sum_gap / STATES, max_of(dist, STATES));
        free(dist);
    }

    /* place * 729, so the PDB index needs no multiply on the target. */
    static uint32_t place_base[NL];
    for (uint32_t l = 0; l < NL; l++)
        place_base[l] = l * NO;

    FILE *f = fopen(out, "w");
    if (!f)
        FAIL("cannot write %s\n", out);
    fprintf(f, "/* Generated by gen_tables.c. Do not edit. */\n\n");
    emit_u16(f, "pm0", pm[0], NP);
    emit_u16(f, "pm1", pm[1], NP);
    emit_u16(f, "pm2", pm[2], NP);
    emit_u16(f, "om0", om[0], NO);
    emit_u16(f, "om1", om[1], NO);
    emit_u16(f, "om2", om[2], NO);
    emit_u8(f, "lm0", lm[0], NL);
    emit_u8(f, "lm1", lm[1], NL);
    emit_u8(f, "lm2", lm[2], NL);
    emit_u32(f, "place_base", place_base, NL);
    emit_u8(f, "pdb_perm", packed_perm, sizeof packed_perm);
    emit_u8(f, "pdb_ol", packed_ol, sizeof packed_ol);
    fclose(f);

    uint32_t total = (uint32_t) (sizeof pm + sizeof om + sizeof lm +
                                 sizeof place_base + sizeof packed_perm +
                                 sizeof packed_ol);
    printf("wrote %s: %u bytes of tables (budget 131072)\n", out, total);
    return 0;
}
