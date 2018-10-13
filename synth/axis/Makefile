
VERILOG_TOP = axis_fifo.sv
CPP_SOURCES = tb/test_axis_fifo.cpp /usr/share/verilator/include/verilated.cpp /usr/share/verilator/include/verilated_vcd_c.cpp
BINARY_NAME = test_axis_fifo

OBJDIR = obj_dir

VERILATOR = verilator
VERILATOR_FLAGS = -I../other --trace --cc -CFLAGS '-Wall -Wextra -g '

CC = g++

# Add source to vpath so that make will automatically search for them
# sort avoids duplication
vpath %.cpp $(sort $(dir $(CPP_SOURCES)))
# Now the objects can safely be set to the cpp sources, but without the directory
CPP_OBJ = $(patsubst %.cpp, $(OBJDIR)/%.o, $(notdir $(CPP_SOURCES)))

.PHONY: all sim verilated verilated_lib clean
all : $(BINARY_NAME)

$(BINARY_NAME): verilated_lib $(CPP_OBJ)
	$(CC) $(CPP_OBJ) obj_dir/Vaxis_fifo__ALL.a -o $(BINARY_NAME)

# All of the objects can be made from the respective .cpp file
# Make can find these okay since vpath is set
$(OBJDIR)/%.o : %.cpp
	$(CC) -c -I/usr/share/verilator/include -Iobj_dir/ $< -o $@

verilated:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_TOP)

verilated_lib: verilated
	$(MAKE) --no-print-directory -C $(OBJDIR)/ -f Vaxis_fifo.mk


clean:
	rm -r obj_dir $(BINARY_NAME)
