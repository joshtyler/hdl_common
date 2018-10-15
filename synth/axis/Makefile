# This file is not supposed to be made directly
# It should instead be included (perhaps in a nested fashion from the top level makefile)
# Read the comments in the top level makefile for details

# This gives us the current directory relative to the root makefile
# patsubst removes the annoying slash we get on the end otherwise
# We need a unique name otherwise we'll overwrite the value of the calling Makefile
CUR_DIR_AXIS := $(patsubst %/, %, $(dir $(lastword $(MAKEFILE_LIST))))

#$(info Vlog inc dirs before $(VLOG_INC_DIRS))

vpath %.cpp $(CUR_DIR_AXIS)/tb
VLOG_INC_DIRS += $(CUR_DIR_AXIS)

VLOG_SOURCES += axis_fifo.sv
CPP_SOURCES += test_axis_fifo.cpp

VLOG_SOURCES += axis_register.sv
CPP_SOURCES += test_axis_register.cpp

VLOG_SOURCES += axis_broadcaster.sv
CPP_SOURCES += test_axis_broadcaster.cpp
