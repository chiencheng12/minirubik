# IDA* solver (separate from the baseline Makefile in the repo root).
#
#   make            build gen_tables, tables.h and the host solver ./fast
#   make check      gates H1, H2, H4 (gen_tables) and H3 (check, ~1 min)
#   make rv32       cross-compile fast.c for rv32i and verify that it calls
#                   no __mulsi3 / __divsi3 / __udivsi3 / __modsi3 / __umodsi3

CC ?= cc
CFLAGS ?= -O2 -std=c99 -Wall -Wextra -Wpedantic
RV_CC ?= riscv64-elf-gcc
RV_CFLAGS ?= -O2 -march=rv32i -mabi=ilp32 -ffreestanding -std=c99 -Wall -Wextra

.PHONY: all check rv32 clean

all: fast

gen_tables: gen_tables.c
	$(CC) $(CFLAGS) $< -o $@

tables.h: gen_tables
	./gen_tables $@

fast: host_main.c fast.c fast.h tables.h
	$(CC) $(CFLAGS) host_main.c fast.c -o $@

check_all: check.c fast.c fast.h tables.h
	$(CC) $(CFLAGS) check.c fast.c -o $@

check: gen_tables check_all fast
	./gen_tables tables.h
	./check_all
	@test "$$(./fast 21345671111111 | wc -w | tr -d ' ')" = 11 && \
		echo "T6 (host): 21345671111111 -> 11 moves"

fast.rv32.s: fast.c fast.h tables.h
	$(RV_CC) $(RV_CFLAGS) -S fast.c -o $@

rv32: fast.rv32.s
	@if grep -E '__(mul|div|udiv|mod|umod)si3' $<; then \
		echo "rv32: library arithmetic call found"; exit 1; \
	else echo "rv32: no multiply/divide helper calls in $<"; fi

# C reference build on Ripes:  make ripes STATE=12347651111111
# (Ripes prints the NUL terminator of each string, hence the tr.)
RIPES ?= /Applications/Ripes.app/Contents/MacOS/Ripes
STATE ?= 21345671111111

fast.rv32.elf: rv32_main.c fast.c fast.h tables.h
	$(RV_CC) $(RV_CFLAGS) -nostdlib -nostartfiles -DSTATE='"$(STATE)"' \
		-Wl,-Ttext=0 -Wl,-e,_start -o $@ rv32_main.c fast.c

ripes: FORCE
	rm -f fast.rv32.elf
	$(MAKE) fast.rv32.elf STATE=$(STATE)
	$(RIPES) --mode cli -t elf --src fast.rv32.elf --proc RV32_ISS --iret \
		| tr -d '\000'

FORCE:

clean:
	rm -f gen_tables fast check_all fast.rv32.s fast.rv32.elf
