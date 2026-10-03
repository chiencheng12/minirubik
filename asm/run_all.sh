#!/bin/sh
# Run build/cube_cli.s on Ripes RV32_ISS for every state read from stdin
# (one 14-digit state per line) and print "STATE<TAB>MOVES<TAB>IRET".
# Runs JOBS (default 8) Ripes processes in parallel.
#
#   ../opt/verify list 11 | ./run_all.sh > results/dist11.tsv
#   ../opt/verify check < results/dist11.tsv
set -e
cd "$(dirname "$0")"
RIPES=${RIPES:-/Applications/Ripes.app/Contents/MacOS/Ripes}
PROC=${PROC:-RV32_ISS}
JOBS=${JOBS:-8}
SRC=${SRC:-build/cube_cli.s}
export RIPES PROC SRC
tmp=$(mktemp -d)
export tmp

xargs -n 1 -P "$JOBS" ./run_one.sh
rmdir "$tmp"
