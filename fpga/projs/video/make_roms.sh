#!/bin/bash
#
# @author Tobias Weber
# @date 1-June-2024
# @license see 'LICENSE' file
#

# tools
GENFONT=../../../tools/genfont/build/genfont
GENROM=../../../tools/genrom/build/genrom

echo -e "Using tool: $(which $GENFONT)"
echo -e "Using tool: $(which $GENROM)"


echo -e "Creating font rom..."
${GENFONT} -h 24 -w 24 --target_height 24 --target_pitch 2 --check_bounds 1 -t vhdl -s 1 -o font.vhdl
