#!/bin/sh
# Helper for run_all.sh: run one state, print "STATE<TAB>MOVES<TAB>IRET".
s=$1
f="$tmp/$s.s"
sed "s/^input: .*/input:      .string \"$s\"/" "$SRC" > "$f"
out=$("$RIPES" --mode cli -t asm --src "$f" --proc "$PROC" --iret | tr -d '\000')
moves=$(printf '%s\n' "$out" | head -1)
iret=$(printf '%s\n' "$out" | awk '/instructions retired/ { getline; print }')
printf '%s\t%s\t%s\n' "$s" "$moves" "$iret"
rm -f "$f"
