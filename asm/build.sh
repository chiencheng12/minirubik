#!/bin/sh
# Build the two Ripes programs from cube.s (Ripes has no .include / .if):
#   build/cube_cli.s  tables pasted in, renderer lines removed
#   build/cube_gui.s  tables pasted in, renderer kept
# Optional first argument: a 14-digit state to put in the input line.
set -e
cd "$(dirname "$0")"
mkdir -p build

# tables.s is generated (and checked: H1, H2, H4) by opt/gen_tables.c.
if [ ! -s tables.s ] || [ ../opt/gen_tables.c -nt tables.s ]; then
    ${CC:-cc} -O2 -std=c99 -o ../opt/gen_tables ../opt/gen_tables.c
    (cd ../opt && ./gen_tables tables.h ../asm/tables.s)
fi
state=${1:-}

paste_tables() {
    awk 'FNR == NR { tables = tables $0 "\n"; next }
         /^# @TABLES@$/ { printf "%s", tables; next }
         { print }' tables.s "$1"
}

set_input() {
    if [ -n "$state" ]; then
        sed "s/^input: .*/input:      .string \"$state\"/"
    else
        cat
    fi
}

paste_tables cube.s | set_input \
    | awk '/^#@RENDER_BEGIN/ { skip = 1 } !skip { print } /^#@RENDER_END/ { skip = 0 }' \
    > build/cube_cli.s
paste_tables cube.s | set_input > build/cube_gui.s
