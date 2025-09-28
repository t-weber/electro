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

find_package(JPEG REQUIRED)
find_package(PNG REQUIRED)


include_directories(
	${PROJECT_SOURCE_DIR}
	${Boost_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS}/..
	${JPEG_INCLUDE_DIRS}
	${PNG_INCLUDE_DIRS}
)


add_executable(genrom
	genrom.cpp
	common.cpp common.h
	vhdl.cpp vhdl.h
	sv.cpp sv.h
	v.cpp v.h
	hex.cpp hex.h
	img.cpp img.h
	text.cpp text.h
)


target_link_libraries(genrom
	${Boost_LIBRARIES}
	${JPEG_LIBRARIES}
	${PNG_LIBRARIES}
)
