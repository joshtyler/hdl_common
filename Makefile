#  Copyright (C) 2019 Joshua Tyler
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file LICENSE_LGPL included with this distribution for more
#  information.

# This makefile builds all of the unit tests for hdl_common
# The intermediate outputs produced are:
#    # Verilated static libraries V[module name]__ALL.a
#        # These are the result of verilation of a verilog file
#        # And subsequent building of the library file
#    # Object files for the unit tests
#        # These are the result of compiling the cpp test files.
#        # These are then linked with the top level unit test file, which defines main
# Note, currently no dependancy information is included for make
# So all tests are cleaned and rebuilt each time



VLOG_INC_DIRS =
VLOG_SOURCES =
CPP_SOURCES =

TESTS_TOP = run_unit_tests.cpp
CPP_SOURCES += $(TESTS_TOP)
BINARY_NAME = $(basename $(TESTS_TOP))

OBJDIR = obj_dir

CC = g++
CFLAGS = -Wall -Wextra -g -faligned-new -fsanitize=address

VERILATOR = verilator
VERILATOR_INC_DIR = /usr/share/verilator/include
VERILATOR_FLAGS = $(addprefix -y , $(VLOG_INC_DIRS)) --trace --cc -Mdir $(OBJDIR) -CFLAGS '$(CFLAGS)'

# Add files that verilator requires to be compiled to the sources list
CPP_SOURCES += $(VERILATOR_INC_DIR)/verilated.cpp $(VERILATOR_INC_DIR)/verilated_vcd_c.cpp

# Default target is all - build the unit tests file
.PHONY: all
all : $(BINARY_NAME)

# Rules to verilate files and compile into object file
# This are included at the top because nested makefiles may define custom verilation rules
# The last rule to be defined is the one used (all else being equal), so this ensures custom rules are last

# We can tell a file is verilated if the module header is produced
# N.B we can get away without specifying a .v or .sv extension because verilator searches both!
$(OBJDIR)/V%.h:
	$(VERILATOR) $(VERILATOR_FLAGS) $*

# This compiles the verilated sources into an object file
# It depends on verilation having already happened
$(OBJDIR)/V%__ALL.a: $(OBJDIR)/V%.h
	$(MAKE) --no-print-directory -C $(OBJDIR)/ -f V$*.mk

# This file includes Makefiles in subdirectories that add the actual source files
# These makefiles have the following responsibilities:
# Add themselves to vpath for .cpp, if they contain those files
# Add themselves to VLOG_INC_DIRS if they contain any .sv or .v files
# Add any unit test cpp files to CPP_SOURCES
# Add any verilog files used in unit tests to VLOG_SOURCES
# Provide custom rules for verilation (and a custom name) for verilog modules with non-default generics
# Include makefiles in subdirectories off themselves
include synth/Makefile
#SHELL += -x


# Each module is named the same as its source files
# Minus the extension
VLOG_MODULES = $(basename $(notdir $(VLOG_SOURCES)))

# Each library is named V[module name]__ALL.a
# And it lives in the object directory
VERILATED_LIBS = $(addprefix $(OBJDIR)/,$(addprefix V,$(addsuffix __ALL.a, $(VLOG_MODULES))))

# Each header is named V[module name].h
VERILATED_HEADERS = $(addprefix $(OBJDIR)/,$(addprefix V,$(addsuffix .h, $(VLOG_MODULES))))

# Add source to vpath so that make will automatically search for them
# sort avoids duplication
vpath %.cpp $(sort $(dir $(CPP_SOURCES)))
# Now the objects can safely be set to the cpp source names, but in the object directory
CPP_OBJ = $(patsubst %.cpp, $(OBJDIR)/%.o, $(notdir $(CPP_SOURCES)))

# The binary file depends on all of the compiled unit test object files
# As well as all of the verilated libraries
$(BINARY_NAME): $(CPP_OBJ) $(VERILATED_LIBS) $(VERILATED_HEADERS)
	$(CC) $(CFLAGS) $(CPP_OBJ) $(VERILATED_LIBS) -o $@

# All of the objects can be made from the respective .cpp file + verilated headers
# Make can find these okay since vpath is set
$(OBJDIR)/%.o : %.cpp $(VERILATED_LIBS) $(VERILATED_HEADERS)
	$(CC) $(CFLAGS) -c -I$(VERILATOR_INC_DIR) -I$(OBJDIR) $< -o $@


clean:
	rm -r obj_dir
	rm $(BINARY_NAME)
	#find obj_dir/* -maxdepth 1 ! -name verilated.o -and ! -name verilated_vcd_c.o -and ! -name run_unit_tests.o -type f -delete
