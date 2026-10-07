#!/bin/sh
# 產生單一檔案版本 cube_full.s：cube.s + tables.s，可以直接放進 Ripes 執行（CLI 或 GUI）
cd "$(dirname "$0")"
{ cat cube.s; echo; cat tables.s; } > cube_full.s
echo "wrote cube_full.s"
