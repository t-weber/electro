#!/bin/sh
#
# deletes temporary files
# @author Tobias Weber
# @date January 2024
# @license see 'LICENSE' file
#

find . \(  -name "*.vcd" \
	-o -name "*.cf" \
	-o -name "*.o" \) \
	-exec rm -fv {} \;
