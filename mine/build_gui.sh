#!/bin/sh
# 產生 LED 動畫版：把 cube.s 裡的 "# @ANIMATE@" 換成呼叫 animate，再接上 render.s 和表格
cd "$(dirname "$0")"
mkdir -p build
sed 's/^    # @ANIMATE@$/    jal  ra, animate/' cube.s > build/cube_gui.s
{ echo; cat render.s; echo; cat tables.s; } >> build/cube_gui.s
echo "wrote build/cube_gui.s"
