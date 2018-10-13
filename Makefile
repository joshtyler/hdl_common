# This makefile builds all of the unit tests for hdl_common
# The intermediate outputs produced are:
#    # Verilated static libraries V[module name]__ALL.a
#        # These are the result of verilation of a verilog file
#        # And subsequent building of the library file
#    # Object files for the unit tests
#        # These are the result of compiling the cpp test files.
#        # These are then linked with the top level unit test file, which defines main


VLOG_SOURCES = synth/axis/axis_fifo.sv
CPP_SOURCES = synth/axis/tb/test_axis_fifo.cpp
BINARY_NAME = test_axis_fifo

VLOG_INC_DIRS = synth/other synth/axis

OBJDIR = obj_dir

VERILATOR = verilator
VERILATOR_INC_DIR = /usr/share/verilator/include
VERILATOR_FLAGS = $(addprefix -y , $(VLOG_INC_DIRS)) --trace --cc -Mdir $(OBJDIR) -CFLAGS '-Wall -Wextra -g '

# Add files that verilator requires to be compiled to the sources list
CPP_SOURCES += $(VERILATOR_INC_DIR)/verilated.cpp $(VERILATOR_INC_DIR)/verilated_vcd_c.cpp

CC = g++

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
$(OBJDIR)/V%.h:
	$(VERILATOR) $(VERILATOR_FLAGS) $*.sv

# This compiles the verilated sources into an object file
# It depends on verilation having already happened
$(OBJDIR)/V%__ALL.a: $(OBJDIR)/V%.h
	$(MAKE) --no-print-directory -C $(OBJDIR)/ -f V$*.mk


clean:
	rm -r obj_dir $(BINARY_NAME)
