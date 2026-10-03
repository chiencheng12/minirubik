/* Gate H3 (and a host version of T5): solve every one of the 3,674,160
 * states with fast_solve and check that
 *   - the returned length equals the exact BFS distance (optimality), and
 *   - applying the returned moves reaches the solved state.
 * The oracle uses its own move code and BFS, independent of tables.h.
 * Also reports node counts, which drive the instruction count on Ripes.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "fast.h"

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

static uint32_t rank_state(const state_t *s)
{
    uint32_t p = 0, o = 0;
    for (int i = 0; i < N; i++) {
        uint32_t smaller = 0;
        for (int j = i + 1; j < N; j++)
            smaller += s->p[j] < s->p[i];
        p = p * (uint32_t) (N - i) + smaller;
    }
    for (int i = 0; i < 6; i++)
        o = o * 3 + s->o[i];
    return p * NO + o;
}

static void unrank_state(uint32_t rank, state_t *s)
{
    uint8_t avail[N] = {0, 1, 2, 3, 4, 5, 6};
    uint32_t p = rank / NO, o = rank % NO, f = 720;
    int sum = 0;
    for (int i = 0; i < N; i++) {
        uint32_t q = p / f;
        p %= f;
        s->p[i] = avail[q];
        for (uint32_t j = q; j + 1 < (uint32_t) (N - i); j++)
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

int main(void)
{
    uint8_t *dist = malloc(STATES);
    uint32_t *queue = malloc(STATES * sizeof *queue);
    uint32_t head = 0, tail = 0;
    state_t s;
    memset(dist, 0xff, STATES);
    dist[0] = 0;
    queue[tail++] = 0;
    while (head < tail) {
        uint32_t x = queue[head++];
        unrank_state(x, &s);
        for (int f = 0; f < 3; f++) {
            state_t t = s;
            for (int k = 0; k < 3; k++) {
                t = quarter(t, f);
                uint32_t y = rank_state(&t);
                if (dist[y] == 0xff) {
                    dist[y] = (uint8_t) (dist[x] + 1);
                    queue[tail++] = y;
                }
            }
        }
    }
    free(queue);
    if (tail != STATES) {
        puts("oracle BFS incomplete");
        return 1;
    }

    clock_t start = clock();
    uint32_t worst_nodes[12] = {0}, worst_state[12] = {0};
    uint64_t total_nodes[12] = {0}, count[12] = {0};
    for (uint32_t r = 0; r < STATES; r++) {
        char in[15];
        uint8_t path[11];
        unrank_state(r, &s);
        for (int i = 0; i < N; i++) {
            in[i] = (char) ('1' + s.p[i]);
            in[i + N] = (char) ('1' + s.o[i]);
        }
        in[14] = '\0';
        int len = fast_solve(in, path);
        if (len != dist[r]) {
            printf("H3 FAIL %s: length %d, optimal %d\n", in, len, dist[r]);
            return 1;
        }
        for (int i = 0; i < len; i++)
            for (int k = 0; k <= path[i] % 3; k++)
                s = quarter(s, path[i] / 3);
        if (rank_state(&s) != 0) {
            printf("T5 FAIL %s: path does not reach solved\n", in);
            return 1;
        }
        int d = dist[r];
        count[d]++;
        total_nodes[d] += fast_nodes;
        if (fast_nodes > worst_nodes[d]) {
            worst_nodes[d] = fast_nodes;
            worst_state[d] = r;
        }
    }
    double secs = (double) (clock() - start) / CLOCKS_PER_SEC;
    printf("H3 ok: all %u states solved optimally, paths verified (%.1f s)\n",
           STATES, secs);
    puts("dist   states   mean nodes   worst nodes   worst state");
    for (int d = 0; d <= 11; d++) {
        char in[15] = "";
        if (count[d]) {
            unrank_state(worst_state[d], &s);
            for (int i = 0; i < N; i++) {
                in[i] = (char) ('1' + s.p[i]);
                in[i + N] = (char) ('1' + s.o[i]);
            }
            in[14] = '\0';
        }
        printf("%4d %8llu %12.1f %13u   %s\n", d, (unsigned long long) count[d],
               count[d] ? (double) total_nodes[d] / (double) count[d] : 0.0,
               worst_nodes[d], in);
    }
    return 0;
}
