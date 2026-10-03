/* Host helpers for checking the Ripes runs (T5, T6, T7).
 *
 *   ./verify list D      print every state at exact distance D (one per line)
 *   ./verify check       read lines "STATE<TAB>MOVES<TAB>IRET" on stdin and
 *                        check that MOVES solves STATE with optimal length;
 *                        prints a summary of the instruction counts
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

static void to_string(const state_t *s, char *in)
{
    for (int i = 0; i < N; i++) {
        in[i] = (char) ('1' + s->p[i]);
        in[i + N] = (char) ('1' + s->o[i]);
    }
    in[14] = '\0';
}

static int list(int want)
{
    uint8_t *dist = malloc(STATES);
    state_t *queue = malloc(STATES * sizeof *queue);
    uint32_t head = 0, tail = 0;
    memset(dist, 0xff, STATES);
    state_t s = {{0, 1, 2, 3, 4, 5, 6}, {0}};
    dist[0] = 0;
    queue[tail++] = s;
    while (head < tail) {
        state_t x = queue[head++];
        int dx = dist[rank_state(&x)];
        if (dx == want) {
            char in[15];
            to_string(&x, in);
            puts(in);
        }
        for (int f = 0; f < 3; f++) {
            state_t t = x;
            for (int k = 0; k < 3; k++) {
                t = quarter(t, f);
                uint32_t y = rank_state(&t);
                if (dist[y] == 0xff) {
                    dist[y] = (uint8_t) (dx + 1);
                    queue[tail++] = t;
                }
            }
        }
    }
    return 0;
}

static int check(void)
{
    static const char *const names[9] = {"R",  "R2", "R'", "B", "B2",
                                         "B'", "D",  "D2", "D'"};
    char line[256];
    unsigned long count = 0, worst = 0, sum = 0;
    char worst_state[15] = "";
    while (fgets(line, sizeof line, stdin)) {
        char *state = strtok(line, "\t\n");
        char *moves = strtok(NULL, "\t\n");
        char *iret = strtok(NULL, "\t\n");
        if (!state || !iret) {
            printf("FAIL: malformed line\n");
            return 1;
        }
        state_t s;
        for (int i = 0; i < N; i++) {
            s.p[i] = (uint8_t) (state[i] - '1');
            s.o[i] = (uint8_t) (state[i + N] - '1');
        }
        int len = 0;
        for (char *m = strtok(moves, " "); m; m = strtok(NULL, " ")) {
            int k = 0;
            while (k < 9 && strcmp(m, names[k]))
                k++;
            if (k == 9) {
                printf("FAIL %s: unknown move '%s'\n", state, m);
                return 1;
            }
            for (int q = 0; q <= k % 3; q++)
                s = quarter(s, k / 3);
            len++;
        }
        uint8_t path[11];
        int optimal = fast_solve(state, path);
        if (rank_state(&s) != 0 || len != optimal) {
            printf("FAIL %s: %d moves, solved=%d, optimal %d\n", state, len,
                   rank_state(&s) == 0, optimal);
            return 1;
        }
        unsigned long n = strtoul(iret, NULL, 10);
        count++;
        sum += n;
        if (n > worst) {
            worst = n;
            memcpy(worst_state, state, 15);
        }
    }
    printf("ok: %lu runs solved optimally; instructions retired: "
           "worst %lu (%s), mean %.0f\n",
           count, worst, worst_state, count ? (double) sum / count : 0.0);
    return 0;
}

int main(int argc, char **argv)
{
    if (argc == 3 && !strcmp(argv[1], "list"))
        return list(atoi(argv[2]));
    if (argc == 2 && !strcmp(argv[1], "check"))
        return check();
    fputs("usage: verify list D | verify check < results.tsv\n", stderr);
    return 2;
}
