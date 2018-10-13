# This makefile builds all of the unit tests for hdl_common
# The intermediate outputs produced are:
#    # Verilated static libraries V[module name]__ALL.a
#        # These are the result of verilation of a verilog file
#        # And subsequent building of the library file
#    # Object files for the unit tests
#        # These are the result of compiling the cpp test files.
#        # These are then linked with the top level unit test file, which defines main

VLOG_INC_DIRS =
VLOG_SOURCES =
CPP_SOURCES =

include synth/Makefile
# This file includes Makefiles in subdirectories that add the actual source files
# These makefiles have the following responsibilities:
	# Add themselves to vpath for .cpp, if they contain those files
	# Add themselves to VLOG_INC_DIRS if they contain any .sv or .v files
	# Add any unit test cpp files to CPP_SOURCES
	# Add any verilog files used in unit tests to VLOG_SOURCES
	# Provide custom rules for verilation (and a custom name) for verilog modules with non-default generics
	# Include makefiles in subdirectories off themselves
# Includes from this file are at the end

TESTS_TOP = run_unit_tests.cpp
CPP_SOURCES += $(TESTS_TOP)
BINARY_NAME = $(basename $(TESTS_TOP))

OBJDIR = obj_dir

CC = g++
CFLAGS = -Wall -Wextra -g

VERILATOR = verilator
VERILATOR_INC_DIR = /usr/share/verilator/include
VERILATOR_FLAGS = $(addprefix -y , $(VLOG_INC_DIRS)) --trace --cc -Mdir $(OBJDIR) -CFLAGS '$(CFLAGS)'

# Add files that verilator requires to be compiled to the sources list
CPP_SOURCES += $(VERILATOR_INC_DIR)/verilated.cpp $(VERILATOR_INC_DIR)/verilated_vcd_c.cpp

# Each module is named the same as its source files
# Minus the extension
VLOG_MODULES = $(basename $(notdir $(VLOG_SOURCES)))

# Each library is named V[module name]__ALL.a
# And it lives in the object directory
VERILATED_LIBS = $(addprefix $(OBJDIR)/,$(addprefix V,$(addsuffix __ALL.a, $(VLOG_MODULES))))

# Add source to vpath so that make will automatically search for them
# sort avoids duplication
vpath %.cpp $(sort $(dir $(CPP_SOURCES)))
# Now the objects can safely be set to the cpp source names, but in the object directory
CPP_OBJ = $(patsubst %.cpp, $(OBJDIR)/%.o, $(notdir $(CPP_SOURCES)))

# Default target is all - build the unit tests file
.PHONY: all
all : $(BINARY_NAME)

# The binary file depends on all of the compiled unit test object files
# As well as all of the verilated libraries
$(BINARY_NAME): $(CPP_OBJ) $(VERILATED_LIBS)
	$(CC) $(CPP_OBJ) $(VERILATED_LIBS) -o $@

# All of the objects can be made from the respective .cpp file + verilated headers
# Make can find these okay since vpath is set
$(OBJDIR)/%.o : %.cpp $(VERILATED_LIBS)
	$(CC) -c -I$(VERILATOR_INC_DIR) -I$(OBJDIR) $< -o $@

# We can tell a file is verilated if the module header is produced
# N.B we can get away without specifying a .v or .sv extension because verilator searches both!
$(OBJDIR)/V%.h:
	$(VERILATOR) $(VERILATOR_FLAGS) $*

# This compiles the verilated sources into an object file
# It depends on verilation having already happened
$(OBJDIR)/V%__ALL.a: $(OBJDIR)/V%.h
	$(MAKE) --no-print-directory -C $(OBJDIR)/ -f V$*.mk


clean:
	rm -r obj_dir $(BINARY_NAME)
