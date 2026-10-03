/* IDA* solver for the 2x2x2 cube, written for RV32I.
 *
 * No multiply, divide or modulo anywhere (GCC would turn them into
 * __mulsi3 / __udivsi3 / __umodsi3 calls on -march=rv32i), no recursion,
 * no heap.  All tables are read-only data from tables.h (115,149 bytes).
 *
 * The search state is three coordinates, each advanced by its own
 * quarter-turn table:  perm (0..5039), orient (0..728), place (0..209).
 * Heuristic: h = max(pdb_perm[perm], pdb_ol[place * 729 + orient]).
 */
#include <stdint.h>

#include "fast.h"
#include "tables.h"

enum { MAX_DEPTH = 11, NO_FACE = 3 };

static const uint16_t *const perm_move[3] = {pm0, pm1, pm2};
static const uint16_t *const orient_move[3] = {om0, om1, om2};
static const uint8_t *const place_move[3] = {lm0, lm1, lm2};

/* Lehmer rank weights (6 - i)!: 720, 120, 24, 6, 2, 1. */
static const uint16_t lehmer_weight[6] = {720, 120, 24, 6, 2, 1};

uint32_t fast_nodes;

/* Two 4-bit entries per byte: even index in the low nibble. */
static inline uint32_t nibble(const uint8_t *table, uint32_t i)
{
    uint32_t byte = table[i >> 1];
    return (i & 1) ? byte >> 4 : byte & 15;
}

static inline uint32_t heuristic(uint32_t perm, uint32_t orient, uint32_t place)
{
    uint32_t a = nibble(pdb_perm, perm);
    uint32_t b = nibble(pdb_ol, place_base[place] + orient);
    return a > b ? a : b;
}

/* Parse "PPPPPPPOOOOOOO" (digits from 1) into the three coordinates.
 * Returns 0 if the string is not a valid cube state. */
static int parse(const char *in, uint32_t *perm, uint32_t *orient,
                 uint32_t *place)
{
    uint8_t p[7], where[7];
    uint32_t seen = 0, sum = 0, o = 0, r = 0;
    for (int i = 0; i < 7; i++) {
        uint32_t d = (uint32_t) (in[i] - '1');
        if (d > 6 || (seen >> d & 1))
            return 0;
        seen |= 1U << d;
        p[i] = (uint8_t) d;
        where[d] = (uint8_t) i;
    }
    for (int i = 7; i < 14; i++) {
        uint32_t d = (uint32_t) (in[i] - '1');
        if (d > 2)
            return 0;
        sum += d;
        if (i < 13)
            o = (o << 1) + o + d; /* o * 3 + d */
    }
    if (in[14] != '\0')
        return 0;
    while (sum >= 3) /* sum % 3, at most 4 iterations */
        sum -= 3;
    if (sum != 0)
        return 0;

    /* Lehmer rank: sum of (number of smaller entries to the right) * weight.
     * The count fits in 3 bits, so the product is at most three shifted
     * copies of the weight, selected by masks.  (A plain repeated-addition
     * loop is not enough: GCC recognizes it and emits __mulsi3.) */
    for (int i = 0; i < 6; i++) {
        uint32_t smaller = 0, w = lehmer_weight[i];
        for (int j = i + 1; j < 7; j++)
            smaller += p[j] < p[i];
        r += (w & -(smaller & 1)) + ((w << 1) & -(smaller >> 1 & 1)) +
             ((w << 2) & -(smaller >> 2 & 1));
    }

    /* place = a * 30 + b' * 5 + c' with shifts: 30a = 32a - 2a, 5b = 4b + b. */
    uint32_t a = where[0], b = where[1], c = where[2];
    uint32_t bb = b - (b > a);
    uint32_t cc = c - (c > a) - (c > b);
    *place = (a << 5) - (a << 1) + (bb << 2) + bb + cc;
    *perm = r;
    *orient = o;
    return 1;
}

int fast_solve(const char *in, uint8_t *path)
{
    /* Node d of the current path, plus the iterator over its children. */
    uint16_t perm[MAX_DEPTH + 1], orient[MAX_DEPTH + 1];
    uint8_t place[MAX_DEPTH + 1];
    uint8_t face[MAX_DEPTH + 1];  /* face being expanded at depth d */
    uint8_t turns[MAX_DEPTH + 1]; /* quarter turns already applied to it */
    uint8_t last[MAX_DEPTH + 1];  /* face that led to depth d */
    uint32_t p0, o0, l0;

    fast_nodes = 0;
    if (!parse(in, &p0, &o0, &l0))
        return -1;
    uint32_t bound = heuristic(p0, o0, l0);
    if (bound == 0)
        return 0;

    for (;; bound++) {
        int d = 0;
        perm[0] = (uint16_t) p0;
        orient[0] = (uint16_t) o0;
        place[0] = (uint8_t) l0;
        face[0] = 0;
        turns[0] = 0;
        last[0] = NO_FACE;

        while (d >= 0) {
            uint32_t f = face[d];
            if (f == last[d]) /* never turn the same face twice in a row */
                f = face[d] = (uint8_t) (f + 1);
            if (f >= 3) { /* all children of node d tried: backtrack */
                d--;
                continue;
            }
            /* The child slot d + 1 holds the previous turn of this face, so
             * one more quarter turn gives the next of X, X2, X'. */
            if (turns[d] == 0) {
                perm[d + 1] = perm[d];
                orient[d + 1] = orient[d];
                place[d + 1] = place[d];
            }
            perm[d + 1] = perm_move[f][perm[d + 1]];
            orient[d + 1] = orient_move[f][orient[d + 1]];
            place[d + 1] = place_move[f][place[d + 1]];
            uint32_t t = ++turns[d];
            path[d] = (uint8_t) ((f << 1) + f + t - 1); /* f * 3 + t - 1 */
            if (t == 3) {
                face[d] = (uint8_t) (f + 1);
                turns[d] = 0;
            }

            fast_nodes++;
            uint32_t h = heuristic(perm[d + 1], orient[d + 1], place[d + 1]);
            uint32_t g = (uint32_t) d + 1;
            if (h == 0) /* both PDBs are zero only at the solved state */
                return (int) g;
            if (g + h > bound)
                continue;
            d++;
            face[d] = 0;
            turns[d] = 0;
            last[d] = (uint8_t) f;
        }
    }
}
