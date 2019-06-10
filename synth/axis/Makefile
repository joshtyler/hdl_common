#  Copyright (C) 2019 Joshua Tyler
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file COPYING included with this distribution for more
#  information.

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

VLOG_SOURCES += axis_packet_fifo.sv
CPP_SOURCES += test_axis_packet_fifo.cpp

VLOG_SOURCES += axis_register.sv
CPP_SOURCES += test_axis_register.cpp

VLOG_SOURCES += axis_padder.sv
CPP_SOURCES += test_axis_padder.cpp

VLOG_INC_DIRS += $(CUR_DIR_AXIS)/tb
VLOG_SOURCES += axis_broadcaster_harness.sv
CPP_SOURCES += test_axis_broadcaster.cpp

VLOG_SOURCES += axis_round_robin_harness.sv
CPP_SOURCES += test_axis_round_robin.cpp

# Custom rule for width converter to test different cases
VLOG_SOURCES += axis_width_converter_1i_1o
VLOG_SOURCES += axis_width_converter_1i_2o
VLOG_SOURCES += axis_width_converter_2i_1o
CPP_SOURCES += test_axis_width_converter.cpp

$(OBJDIR)/Vaxis_width_converter_1i_1o.h:
	$(VERILATOR) $(VERILATOR_FLAGS) -GAXIS_I_BYTES=1 -GAXIS_O_BYTES=1 --prefix $(basename $(notdir $@)) axis_width_converter

$(OBJDIR)/Vaxis_width_converter_1i_2o.h:
	$(VERILATOR) $(VERILATOR_FLAGS) -GAXIS_I_BYTES=1 -GAXIS_O_BYTES=2 --prefix $(basename $(notdir $@)) axis_width_converter

$(OBJDIR)/Vaxis_width_converter_2i_1o.h:
	$(VERILATOR) $(VERILATOR_FLAGS) -GAXIS_I_BYTES=2 -GAXIS_O_BYTES=1 --prefix $(basename $(notdir $@)) axis_width_converter
