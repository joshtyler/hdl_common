#  Copyright (C) 2019 Joshua Tyler
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file LICENSE_LGPL included with this distribution for more
#  information.

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

VLOG_SOURCES += ip_header_gen.sv
CPP_SOURCES += test_ip_header_gen.cpp
