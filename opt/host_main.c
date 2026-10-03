/* Host front end for fast.c: same interface and exit codes as solver.c.
 *   ./fast PPPPPPPOOOOOOO          prints the solution
 *   ./fast --nodes PPPPPPPOOOOOOO  also prints the node count to stderr
 */
#include <stdio.h>
#include <string.h>

#include "fast.h"

static const char *const move_names[9] = {"R",  "R2", "R'", "B", "B2",
                                          "B'", "D",  "D2", "D'"};

int main(int argc, char **argv)
{
    int show_nodes = argc == 3 && !strcmp(argv[1], "--nodes");
    const char *in = argc == 2 ? argv[1] : show_nodes ? argv[2] : NULL;
    uint8_t path[11];
    int len = in ? fast_solve(in, path) : -1;
    if (len < 0) {
        fprintf(stderr, "usage: %s [--nodes] PPPPPPPOOOOOOO\n",
                argc > 0 && argv[0] ? argv[0] : "fast");
        return 2;
    }
    for (int i = 0; i < len; i++)
        printf("%s%s", i ? " " : "", move_names[path[i]]);
    putchar('\n');
    if (show_nodes)
        fprintf(stderr, "nodes %u\n", fast_nodes);
    return fflush(stdout) != 0 || ferror(stdout);
}
