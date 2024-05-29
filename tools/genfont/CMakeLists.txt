#
# @author Tobias Weber
# @date 12-Apr-2024
# @license see 'LICENSE' file
#

cmake_minimum_required(VERSION 3.5)
project(genfont)

enable_language(CXX)
set(CMAKE_CXX_STANDARD 20)

add_compile_options(-std=c++20)
add_compile_options(-Wall -Wextra -Weffc++)


# see: https://cmake.org/cmake/help/latest/module/FindBoost.html
find_package(Boost REQUIRED COMPONENTS program_options)
add_compile_options(${Boost_CXX_FLAGS})

find_package(Freetype REQUIRED)


include_directories(
	${PROJECT_SOURCE_DIR}
	${Boost_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS}/..
	${FREETYPE_INCLUDE_DIRS}
)


add_executable(genfont
	genfont.cpp genfont.h
	vhdl.cpp sv.cpp v.cpp c.cpp
	v_opt.cpp
	main.cpp
)


target_link_libraries(genfont
	${Boost_LIBRARIES}
	${FREETYPE_LIBRARIES}
)
