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

# which tools to run?
build_fs=1
build_testbench=1
create_source_archive=1

num_threads=$(($(nproc)/2+1))


if [ $build_fs -ne 0 ]; then
	run_synth=1
	run_pnr=1
	run_pack=1
else
	run_synth=0
	run_pnr=0
	run_pack=0
fi


# choose program in rom
rom_file=programs/rom_func.dat
rom_addr_bits=5

#rom_file=programs/rom_mult.dat
#rom_file=programs/rom_div.dat
#rom_addr_bits=4


# testbench options
TESTBENCH_DEFS="-DDEBUG -DIS_TESTBENCH"
#TESTBENCH_DEFS+="-D__IN_SIMULATION__"
#TESTBENCH_DEFS+=" -DRAM_DISABLE_PORT2"
TESTBENCH_DEFS+=" -DROM_ADDR_BITS=${rom_addr_bits}"
TESTBENCH_DEFS+=" -DSIM_INTERRUPT"
TESTBENCH_DEFS+=" -DLEDMAT_SEVENSEG"


# files
top_module=cpuctrl
rom_svfile=output/rom.sv
synth_file=output/synth.json
pnr_file=output/pnr.json
pack_file=output/${top_module}.fs
pack_cst_file=output/${top_module}.cst
pack_png_file=output/${top_module}.png
synth_log=output/synth.log
pnr_log=output/pnr.log
src_files="../../clock/clkgen.sv \
	../../sync/debounce_switch.sv \
	../../sync/debounce_button.sv \
	../../sync/edge.sv \
	../../mem/memcpy.sv \
	../../mem/ram_2port.sv \
	../../proc/cpu16.sv \
	../../arithmetics/multiplier.sv \
	../../arithmetics/divider.sv \
	../../comm/serial_tx.sv \
	../../display/ledmatrix.sv \
	../../display/sevenseg.v \
	${rom_svfile} \
	main.sv"

#	../../sync/syncbit.sv \
#	../../sync/syncdata.sv \


# 9k board
target_board=GW1NR-LV9QN88PC6/I5
target_fpga=GW1N-9C
target_freq=27
target_pins_file=pins9k.cst
target_defines="-DUSE_9K"

# 1k board (define RAM_UNPACKED for it to be recognised as BSRAM)
#target_board=GW1NZ-LV1QN48C6/I5
#target_fpga=GW1NZ-1
#target_freq=27
#target_pins_file=pins1k.cst
#target_defines="-DUSE_1K"


# options
#target_defines+=" -DCPU16_DEDICATED_IP"
#target_defines+="-DRAM_DISABLE_PORT2"
target_defines+=" -DRAM_UNPACKED -DRAM_INIT"
target_defines+=" -DLEDMAT_SEVENSEG"
target_defines+=" -DROM_ADDR_BITS=$rom_addr_bits"
target_defines+=" -DCPU_NO_MULT_DIV"


# tools
YOSYS=yosys
NEXTPNR=nextpnr-himbaechel
PACK=gowin_pack
SIM=iverilog

echo -e "Using tool: $(which $YOSYS)"
echo -e "Using tool: $(which $NEXTPNR)"
echo -e "Using tool: $(which $PACK)"
echo -e "Using simulation tool: $(which $SIM)"


if [ ! -e output ]; then
	mkdir output
fi


# create sv rom
echo -e "\nCreating ROM: ${rom_file} -> ${rom_svfile}..."
if [ -e genrom ]; then
	if ! ./genrom -t sv -c 0 -p 1 -d 1 -w 16 --convert_text 1 -o ${rom_svfile} ${rom_file}; then
		exit -1
	fi
else
	echo -e "Error: Could not find genrom tool, get it from tools/genrom."
	exit -1
fi


if [ $create_source_archive -ne 0 ]; then
	echo -e "\nCreating a source archive -> output/src.txz..."
	mkdir -p output/src
	for file in $src_files; do
		cp -v $file output/src
	done
	cp -v $target_pins_file output/src
	tar -Jvcf output/src.txz output/src
fi


if [ $run_synth -ne 0 ]; then
	echo -e "\nRunning Synthesis: sv -> $synth_file..."
	if ! ${YOSYS} -q -d -t -l $synth_log \
		-p "synth_gowin -top $top_module -json $synth_file" \
		$target_defines \
		$src_files
	then
		echo -e "Synthesis failed!"
		exit -1
	fi
fi


if [ $run_pnr -ne 0 ]; then
	echo -e "\nRunning P&R Fitter for $target_fpga: $synth_file & $target_pins_file -> $pnr_file..."
	if ! ${NEXTPNR} --threads $num_threads -q --detailed-timing-report -l $pnr_log \
		--vopt family=$target_fpga --device $target_board --freq $target_freq \
		--placer-heap-cell-placement-timeout 8 \
		--vopt cst=$target_pins_file --json $synth_file --write $pnr_file --top $top_module
		#--placed-svg output/placed.svg --routed-svg output/routed.svg --sdf output/delay.sdf
	then
		echo -e "P&R Fitting failed!"
		exit -1
	fi
fi


if [ $run_pack -ne 0 ]; then
	echo -e "\nGenerating bit stream for $target_fpga: $pnr_file -> $pack_file..."
	if ! ${PACK} -d $target_fpga \
		-o $pack_file --cst $pack_cst_file $pnr_file #--png $pack_png_file
	then
		echo -e "Bit stream generation failed!"
		exit -1
	fi
fi


if [ $build_testbench -ne 0 ]; then
	echo -e "\nBuilding simulation testbench..."
	if ! ${SIM} -g2012 ${TESTBENCH_DEFS} \
		\-o testbench $src_files testbench.sv; then
		echo -e "Building testbench failed!"
		exit -1
	fi

	echo -e "\nRun testbench via, e.g.: ./testbench +iter=2000\n"
fi
