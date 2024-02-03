#
# @author Tobias Weber
# @date 27-Jan-2024
# @license see 'LICENSE' file
#

cmake_minimum_required(VERSION 3.5)
project(genrom)

enable_language(CXX)
set(CMAKE_CXX_STANDARD 20)

add_compile_options(-std=c++20)
add_compile_options(-Wall -Wextra -Weffc++)


# see: https://cmake.org/cmake/help/latest/module/FindBoost.html
find_package(Boost REQUIRED COMPONENTS program_options)
add_compile_options(${Boost_CXX_FLAGS})


include_directories(
	${PROJECT_SOURCE_DIR}
	${Boost_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS}/..
)


add_executable(genrom
	genrom.cpp
	vhdl.cpp vhdl.h
	sv.cpp sv.h
	hex.cpp hex.h
)


target_link_libraries(genrom ${Boost_LIBRARIES})
