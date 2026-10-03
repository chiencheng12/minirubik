#!/bin/zsh
# Stage 1 量測腳本
#   ./measure.sh speed <迴圈次數> <處理器>   例：./measure.sh speed 5000000 RV32_ISS
#   ./measure.sh mem   <byte 數>             例：./measure.sh mem 4000000
#   ./measure.sh ctrl  <byte 數>             例：./measure.sh ctrl 4000000
# 會印出：retired 指令數、模擬時間 (ms)、Ripes 行程的最大記憶體 (bytes)
set -e
RIPES=/Applications/Ripes.app/Contents/MacOS/Ripes
DIR=${0:A:h}
kind=$1; size=$2; proc=${3:-RV32_ISS}
case $kind in
  speed) sym=N ;;
  mem|ctrl) sym=K ;;
  *) echo "用法：$0 speed|mem|ctrl <大小> [處理器]"; exit 2 ;;
esac

tmp=$(mktemp -t stage1).s
sed "s/^\.equ $sym, .*/.equ $sym, $size/" "$DIR/$kind.s" > "$tmp"
log=$(mktemp -t stage1-time)

/usr/bin/time -l "$RIPES" --mode cli -t asm --src "$tmp" --proc "$proc" \
    --iret --exectime 2> "$log" | grep -A1 -E "instructions retired|execution time" \
    | grep -v -- "--"
rss=$(awk '/maximum resident set size/ {print $1}' "$log")
wall=$(awk '/ real / {print $1}' "$log")
echo "===== max RSS (bytes)"
echo "$rss"
echo "===== wall clock incl. startup (s)"
echo "$wall"
echo "(kind=$kind size=$size proc=$proc)"
rm -f "$tmp" "$log"
