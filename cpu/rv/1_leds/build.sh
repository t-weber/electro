#!/bin/bash

#
# rv c++ program building
# @author Tobias Weber (0000-0002-7230-1932)
# @date 24-aug-2025
# @license see 'LICENSE' file
#

# tools
CC=riscv64-elf-gcc
CPP=riscv64-elf-cpp
CXX=riscv64-elf-g++
OBJCPY=riscv64-elf-objcopy
OBJDMP=riscv64-elf-objdump

USE_INTERRUPTS=1
TESTBENCH_DEFS="-DDEBUG"
#TESTBENCH_DEFS+=" -DRAM_DISABLE_PORT2"
CFLAGS="-std=c++20 -O2 -Wall -Wextra -Weffc++"

if [ "$USE_INTERRUPTS" != 0 ]; then
	TESTBENCH_DEFS+=" -DUSE_INTERRUPTS"
fi

#
# base integer (i) and mul/div (m)
# see: https://gcc.gnu.org/onlinedocs/gcc/RISC-V-Options.html
#
if [ "$1" = "64" ]; then
	echo -e "Building 64 bit binary..."
	ISA=rv64im
	ABI=lp64
	USE_64BIT=1
else
	echo -e "Building 32 bit binary..."
	ISA=rv32im
	ABI=ilp32
	USE_64BIT=0
fi

# files
CFILES="../entry/startup.cpp main.cpp"
ENTRYFILE=build/entrypoint.s
LFILE=build/linker.ld
PROGFILE=build/rom.prog
BINFILE=build/rom.bin
ROMFILE=build/rom.sv


# clean old files
rm -rv build
mkdir -p build


# preprocess entrypoint file
echo -e "\n../entry/$(basename ${ENTRYFILE}).in -> ${ENTRYFILE}..."
${CPP} -P -DUSE_64BIT=${USE_64BIT} -DUSE_INTERRUPTS=${USE_INTERRUPTS} \
	../entry/$(basename ${ENTRYFILE}).in -o ${ENTRYFILE}


# preprocess linker file
echo -e "\n../entry/$(basename ${LFILE}).in -> ${LFILE}..."
${CPP} -P -DUSE_64BIT=${USE_64BIT} ../entry/$(basename ${LFILE}).in -o ${LFILE}


# compile & link
echo -e "\n${CFILES} -> ${PROGFILE}..."
if ! ${CXX} ${CFLAGS} -I../lib -time \
	-march=${ISA} -mabi=${ABI} -mcmodel=medany \
	-mno-save-restore -mno-riscv-attribute -mno-fdiv -mdiv \
	-nostartfiles -nolibc -nodefaultlibs -nostdlib++ -nostdlib \
	-fno-builtin -ffreestanding -static \
	-DUSE_INTERRUPTS=${USE_INTERRUPTS} \
	-T ${LFILE} -o ${PROGFILE} ${ENTRYFILE} ${CFILES}; then
	exit -1
fi

${OBJDMP} -tDS "${PROGFILE}"


# get binary image
echo -e "\n${PROGFILE} -> ${BINFILE}..."
if ! ${OBJCPY} -v -O binary "${PROGFILE}" "${BINFILE}"; then
	exit -1
fi

hexdump -C "${BINFILE}"


# create sv rom
echo -e "\n${BINFILE} -> ${ROMFILE}..."
if [ -e genrom ]; then
	if ! ./genrom -t sv -c 0 -p 1 -d 1 -w 32 -o ${ROMFILE} "${BINFILE}"; then
		exit -1
	fi
else
	echo -e "Error: Could not find genrom tool, get it from tools/genrom."
	exit -1
fi


# build sv testbench
echo -e "\nBuilding testbench \"build/rv_tb\"..."
if [ -d externals ]; then
	if ! iverilog -g2012 ${TESTBENCH_DEFS} \
		\-o build/rv_tb \
		../../../fpga_sv/mem/ram_2port.sv \
		../../../fpga_sv/mem/memcpy.sv \
		../../../fpga_sv/mem/memsel.sv \
		../../../fpga_sv/clock/clkgen.sv \
		../../../fpga_sv/sync/debounce_switch.sv \
		../../../fpga_sv/sync/debounce_button.sv \
		externals/picorv32.v \
		${ROMFILE} rv_main.sv rv_tb.sv; then
		exit -1
	fi
else
	echo -e "Error: Could not find externals, use the ./get_externals.sh script."
	exit -1
fi

echo -e "\nRun testbench via, e.g.:\n\t./build/rv_tb +iter=1900\n"
