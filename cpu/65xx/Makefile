#
# @author Tobias Weber
# @date 16-sep-2023
# @license see 'LICENSE' file
#

.PRECIOUS: %.asm
.PHONY: all clean

all: test_io.rom test_mem.rom test_timer.rom test_irq.rom

clean:
	rm -vf *.o *.rom


%.rom: %.o mem.cfg
	ld65 -C mem.cfg -o $@ $<

%.o: %.asm defs.inc
	ca65 --cpu 65c02 -o $@ $<

%.asm: %.c65
	cc65 --cpu 65c02 -t none -o $@ $<
