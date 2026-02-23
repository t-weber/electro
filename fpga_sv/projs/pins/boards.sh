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


# boards
if [[ "$target_hw" == "25k" ]]; then
	# 20k board
	echo -e "Using 25k board."

	target_board=GW5A-LV25MG121NC1/I0
	target_fpga=GW5A-25
	target_freq=50
	target_pins_file=pins25k.cst
	target_clocks_file=clocks25k.sdc
	target_defines="-DUSE_25K"

elif [[ "$target_hw" == "20k" ]]; then
	# 20k board
	echo -e "Using 20k board."

	target_board=GW2A-LV18QN88C8/I7
	#target_board=GW2AR-LV18QN88C8/I7
	target_fpga=GW2A-18
	#target_fpga=GW2AR-18
	target_freq=27
	target_pins_file=pins20k.cst
	target_clocks_file=clocks20k.sdc
	target_defines="-DUSE_20K"

elif [[ "$target_hw" == "9k" ]]; then
	# 9k board
	echo -e "Using 9k board."

	target_board=GW1NR-LV9QN88PC6/I5
	target_fpga=GW1N-9C
	target_freq=27
	target_pins_file=pins9k.cst
	target_clocks_file=clocks9k.sdc
	target_defines="-DUSE_9K"

elif [[ "$target_hw" == "1k" ]]; then
	# 1k board
	echo -e "Using 1k board."

	target_board=GW1NZ-LV1QN48C6/I5
	target_fpga=GW1NZ-1
	target_freq=27
	target_pins_file=pins1k.cst
	target_clocks_file=clocks1k.sdc
	target_defines="-DUSE_1K"

else
	echo -e "Error: Unknown board selected: \"$target_hw\"."
	exit -1
fi


# tools
YOSYS=yosys
NEXTPNR=nextpnr-himbaechel
PACK=gowin_pack
SIM=iverilog

echo -e "Using tool: $(which $YOSYS)"
echo -e "Using tool: $(which $NEXTPNR)"
echo -e "Using tool: $(which $PACK)"
echo -e "Using simulation tool: $(which $SIM)"
echo -e ""
