cmake_minimum_required(VERSION 3.8)
project(hdl_common_tests)

#SET (CMAKE_CXX_COMPILER             "/usr/bin/clang++")
set (CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fsanitize=address")

find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
if (NOT verilator_FOUND)
  message(FATAL_ERROR "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable")
endif()

add_subdirectory(synth)

# See https://github.com/catchorg/Catch2/issues/421 for the slightly way of doing this
# Needed to make catch2 detect tests in libraries
add_executable(all_tests_exec $<TARGET_OBJECTS:axis_object> $<TARGET_OBJECTS:network_object> run_unit_tests.cpp sim/axis/AXIS.h)
target_link_libraries(all_tests_exec axis_object network_object)
add_test(NAME all_tests COMMAND all_tests_exec)

