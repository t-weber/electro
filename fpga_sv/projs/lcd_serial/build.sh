#!/bin/bash

#
# @author Tobias Weber
# @date 9-May-2024
# @license see 'LICENSE' file
#
# references:
#   - https://github.com/YosysHQ/yosys/tree/main/examples/gowin
#   - https://github.com/YosysHQ/apicula
#   - https://learn.lushaylabs.com/os-toolchain-manual-installation
#

build_roms=1
run_synth=1
run_pnr=1
run_pack=1
num_threads=$(($(nproc)/2+1))

top_module=lcd_serial

synth_file=output/synth.json
pnr_file=output/pnr.json
pack_file=output/${top_module}.fs
pack_cst_file=output/${top_module}.cst
pack_png_file=output/${top_module}.png
synth_log=output/synth.log
pnr_log=output/pnr.log
src_files="../../lib/sync/debounce_button.sv \
	../../lib/sync/debounce_switch.sv \
	../../lib/clock/clkgen.sv \
	../../lib/comm/serial.sv \
	../../lib/display/video_serial.sv \
	../../lib/display/testpattern.sv \
	../../lib/display/tile.sv \
	../../lib/mem/ram_2port.sv \
	font.sv textmem.sv \
	textmem_fgcol.sv textmem_bgcol.sv \
	main.sv"

# 9k board
target_board=GW1NR-LV9QN88PC6/I5
target_fpga=GW1N-9C
target_freq=27
target_pins_file=pins9k.cst

# 1k board
#target_board=GW1NZ-LV1QN48C6/I5
#target_fpga=GW1NZ-1
#target_freq=27
#target_pins_file=pins1k.cst

# tools
YOSYS=yosys
NEXTPNR=nextpnr-himbaechel
PACK=gowin_pack
GENFONT=../../../tools/genfont/build/genfont
GENROM=../../../tools/genrom/build/genrom
gen_type=sv

echo -e "Using tool: $(which $YOSYS)"
echo -e "Using tool: $(which $NEXTPNR)"
echo -e "Using tool: $(which $PACK)"
echo -e "Using tool: $(which $GENFONT)"
echo -e "Using tool: $(which $GENROM)"


if [ $build_roms -ne 0 ]; then
	echo -e "Creating font rom..."
	${GENFONT} -f DejaVuSansMono.ttf \
		-h 20 -w 24 \
		--target_height 20 --target_pitch 2 --target_left 1 \
		--pitch_bits 6 --sync 1 -t $gen_type -o font.sv


	echo -e "Creating text buffer..."
	 txt="--------------------"
	txt+="|      Line 1      |"
	txt+="|      Line 2      |"
	txt+="|      Line 3      |"
	txt+="|      Line 4      |"
	txt+="--------------------"
	echo -en "$txt" > textmem.txt

	${GENROM} -l 20 -t $gen_type -p 1 -d 1 -f 0 -m textmem \
		textmem.txt -o textmem.sv
	${GENROM} -l 20 -t $gen_type -p 1 -d 1 -f 0 -m textmem_fgcol \
		-r "1111111111111111" -n 120 -o textmem_fgcol.sv
	${GENROM} -l 20 -t $gen_type -p 1 -d 1 -f 0 -m textmem_bgcol \
		-r "0000000000011111" -n 120 -o textmem_bgcol.sv
fi


if [ ! -e output ]; then
	mkdir output
fi


if [ $run_synth -ne 0 ]; then
	echo -e "Running Synthesis: sv -> $synth_file..."
	if ! ${YOSYS} -q -d -t -l $synth_log \
		-D RAM_UNPACKED \
		-p "synth_gowin -top $top_module -json $synth_file" \
		$src_files
	then
		echo -e "Synthesis failed!"
		exit -1
	fi
fi


if [ $run_pnr -ne 0 ]; then
	echo -e "Running P&R Fitter for $target_fpga: $synth_file & $target_pins_file -> $pnr_file..."
	if ! ${NEXTPNR} --threads $num_threads -q --detailed-timing-report -l $pnr_log \
		--vopt family=$target_fpga --device $target_board --freq $target_freq --parallel-refine \
		--vopt cst=$target_pins_file --json $synth_file --write $pnr_file --top $top_module \
		#--placed-svg output/placed.svg --routed-svg output/routed.svg --sdf output/delay.sdf
	then
		echo -e "P&R Fitting failed!"
		exit -1
	fi
fi


if [ $run_pack -ne 0 ]; then
	echo -e "Generating bit stream for $target_fpga: $pnr_file -> $pack_file..."
	if ! ${PACK} -d $target_fpga \
		-o $pack_file --cst $pack_cst_file $pnr_file #--png $pack_png_file
	then
		echo -e "Bit stream generation failed!"
		exit -1
	fi
fi
