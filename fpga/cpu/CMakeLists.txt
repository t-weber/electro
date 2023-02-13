#
# simple cpu compiler and vm
# @author Tobias Weber (orcid: 0000-0002-7230-1932)
# @date 5-february 2023
# @license see 'LICENSE' file
#

cmake_minimum_required(VERSION 3.12)

project(lalr1)
enable_language(CXX)

list(APPEND CMAKE_MODULE_PATH
	${PROJECT_SOURCE_DIR}
	/usr/local/lib/cmake
	/usr/local/lib64/cmake
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_VERBOSE_MAKEFILE ON)

add_compile_options(-Wall -Wextra -Weffc++)
#add_compile_options(-fPIC)


option(BUILD_EXAMPLES "build example compilers" TRUE)


find_package(Boost REQUIRED COMPONENTS program_options)
add_definitions(${Boost_CXX_FLAGS})

find_package(Threads REQUIRED)
find_package(LibLalr1)


include(GNUInstallDirs)

include_directories(
	${PROJECT_SOURCE_DIR}
	${CMAKE_CURRENT_BINARY_DIR}
	${Boost_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS}/..
)


# compiler library
add_library(script STATIC
	compiler/lexer.cpp compiler/lexer.h
	compiler/ast_printer.cpp compiler/ast_printer.h
	compiler/ast_asm.cpp compiler/ast_asm.h
	vm/opcodes.h
	vm/types.h
	compiler/symbol.cpp compiler/symbol.h
	compiler/ast.h
)

target_link_libraries(script ${Boost_LIBRARIES}
	${LibLalr1_LIBRARIES}
)


# vm library
add_library(script-vm STATIC
	vm/vm.cpp vm/vm.h
	vm/vm_softints.cpp
	vm/vm_memdump.cpp
	vm/opcodes.h vm/helpers.h
)

target_link_libraries(script-vm
	${Boost_LIBRARIES}
	$<$<TARGET_EXISTS:Threads::Threads>:Threads::Threads>
)


# vm
add_executable(vm vm/main.cpp)
target_link_libraries(vm script-vm)


# script compiler generator
add_executable(compilergen
	compiler/compilergen.cpp
	compiler/grammar.cpp compiler/grammar.h
)

target_include_directories(compilergen
	PUBLIC ${LibLalr1_INCLUDE_DIRECTORIES}
)

target_link_libraries(compilergen
	${LibLalr1_LIBRARIES}
	${Boost_LIBRARIES}
)

# script compiler
if(EXISTS "${CMAKE_BINARY_DIR}/script_parser.cpp" OR EXISTS "${CMAKE_BINARY_DIR}/script.tab")
	add_executable(compiler
		compiler/compiler.cpp
		compiler/grammar.cpp compiler/grammar.h
	)

	target_include_directories(compiler
		PUBLIC ${LibLalr1_INCLUDE_DIRECTORIES})
endif()

if(EXISTS "${CMAKE_BINARY_DIR}/script_parser.cpp")
		target_link_libraries(compiler script script-vm
	)
elseif(EXISTS "${CMAKE_BINARY_DIR}/script.tab")
	target_link_libraries(compiler script script-vm
		${LibLalr1Parser_LIBRARIES}
	)
endif()
