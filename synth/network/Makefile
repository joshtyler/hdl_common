# This file is not supposed to be made directly
# It should instead be included (perhaps in a nested fashion from the top level makefile)
# Read the comments in the top level makefile for details

# This gives us the current directory relative to the root makefile
# patsubst removes the annoying slash we get on the end otherwise
# We need a unique name otherwise we'll overwrite the value of the calling Makefile
CUR_DIR_NETWORK := $(patsubst %/, %, $(dir $(lastword $(MAKEFILE_LIST))))

#$(info Vlog inc dirs before $(VLOG_INC_DIRS))

vpath %.cpp $(CUR_DIR_NETWORK)/tb
VLOG_INC_DIRS += $(CUR_DIR_NETWORK)

VLOG_SOURCES += udp_checksum.sv
CPP_SOURCES += test_udp_checksum.cpp
