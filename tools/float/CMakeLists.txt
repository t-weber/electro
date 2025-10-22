#
# @author Tobias Weber (orcid: 0000-0002-7230-1932)
# @date 20-May-2023
# @license see 'LICENSE' file
#

cmake_minimum_required(VERSION 3.5)
project(float)

enable_language(CXX)
set(CMAKE_CXX_STANDARD 20)

add_compile_options(-std=c++20)
add_compile_options(-Wall -Wextra -Weffc++)


# see: https://cmake.org/cmake/help/latest/module/FindBoost.html
find_package(Boost)
add_compile_options(${Boost_CXX_FLAGS})


find_package(Qt6Core REQUIRED)
find_package(Qt6Gui REQUIRED)
find_package(Qt6Widgets REQUIRED)
find_package(Qt6Svg REQUIRED)

set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)

if(TARGET Qt6::Core)
	message(NOTICE "Using Qt 6.")
	list(APPEND QtTargets Qt6::Core Qt6::Gui Qt6::Widgets)
elseif(TARGET Qt5::Core)
	message(NOTICE "Using Qt 5.")
	list(APPEND QtTargets Qt5::Core Qt5::Gui Qt5::Widgets)
endif()


include_directories(
	${PROJECT_SOURCE_DIR}
	${Boost_INCLUDE_DIRS} ${Boost_INCLUDE_DIRS}/..
)


add_executable(float
	main.cpp
	float_dlg.cpp float_dlg.h
	arb_float.h
)


target_link_libraries(float
	${QtTargets}
)
