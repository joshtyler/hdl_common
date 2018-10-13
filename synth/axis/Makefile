
VERILOG_TOP = axis_fifo.sv
CPP_SOURCES = tb/test_axis_fifo.cpp
BINARY_NAME = test_axis_fifo

OBJDIR = obj_dir

VERILATOR = verilator
VERILATOR_INC_DIR = /usr/share/verilator/include
VERILATOR_FLAGS = -I../other --trace --cc -Mdir $(OBJDIR) -CFLAGS '-Wall -Wextra -g '

# Add files that verilator requires to be compiled to the sources list
CPP_SOURCES += $(VERILATOR_INC_DIR)/verilated.cpp $(VERILATOR_INC_DIR)/verilated_vcd_c.cpp

CC = g++

VERILOG_MODULE = $(basename $(notdir $(VERILOG_TOP)))

# Add source to vpath so that make will automatically search for them
# sort avoids duplication
vpath %.cpp $(sort $(dir $(CPP_SOURCES)))
# Now the objects can safely be set to the cpp source names, but in the object directory
CPP_OBJ = $(patsubst %.cpp, $(OBJDIR)/%.o, $(notdir $(CPP_SOURCES)))

.PHONY: all
all : $(BINARY_NAME)

# The binary file depends on the verilated library and the compiled cpp objects
$(BINARY_NAME): $(OBJDIR)/V$(VERILOG_MODULE)__ALL.a $(CPP_OBJ)
	$(CC) $(CPP_OBJ) $(OBJDIR)/V$(VERILOG_MODULE)__ALL.a -o $(BINARY_NAME)

# All of the objects can be made from the respective .cpp file
# Make can find these okay since vpath is set
$(OBJDIR)/%.o : %.cpp
	$(CC) -c -I$(VERILATOR_INC_DIR) -I$(OBJDIR) $< -o $@

# This rule verilates the top level module
# It produces the module header
$(OBJDIR)/V$(VERILOG_MODULE).h:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_TOP)

# This compiles the verilated sources into an object file
# It depends on verilation having already happened
$(OBJDIR)/V$(VERILOG_MODULE)__ALL.a: $(OBJDIR)/V$(VERILOG_MODULE).h
	$(MAKE) --no-print-directory -C $(OBJDIR)/ -f V$(VERILOG_MODULE).mk


clean:
	rm -r obj_dir $(BINARY_NAME)
