VERILATOR = verilator
#VERILATOR_FLAGS = --trace --cc --exe -CFLAGS '-Wall -Wextra -g -fno-stack-protector'
VERILATOR_FLAGS = -I../other --trace --cc -CFLAGS '-Wall -Wextra -g '

VERILOG_TOP = axis_fifo.sv

CC = g++
CPP_SOURCES = tb/test_axis_fifo.cpp /usr/share/verilator/include/verilated.cpp /usr/share/verilator/include/verilated_vcd_c.cpp
BINARY_NAME = test_axis_fifo

#OBJECTS = test_axis_fifo.o obj_dir/Vaxis_fifo__ALLcls.o  obj_dir/Vaxis_fifo__ALLsup.o Vaxis_fifo__Trace.o  Vaxis_fifo__Trace__Slow.o
OBJECTS = test_axis_fifo.o verilated.o verilated_vcd_c.o

.PHONY: all sim verilated verilated_lib clean
all : $(BINARY_NAME)

#sim : verilated_lib
#	$(CC) -I/usr/share/verilator/include -Iobj_dir/ $(CPP_SOURCES) obj_dir/Vaxis_fifo__ALL.a -o $(BINARY_NAME)
#	$(CC) -I/usr/share/verilator/include -Iobj_dir/ $(CPP_SOURCES) obj_dir/Vaxis_fifo.cpp obj_dir/Vaxis_fifo__Syms.cpp obj_dir/Vaxis_fifo__Trace.cpp obj_dir/Vaxis_fifo__Trace__Slow.cpp -o test_eth_crc
#	$(CC) -I/usr/share/verilator/include -Iobj_dir/ obj_dir/Vaxis_fifo__ALLcls.o obj_dir/Vaxis_fifo__ALLsup.o obj_dir/verilated.o obj_dir/verilated_vcd_c.o $(CPP_SOURCES)  -o test_eth_crc

$(BINARY_NAME): verilated_lib $(OBJECTS)
	$(CC) $(OBJECTS) obj_dir/Vaxis_fifo__ALL.a -o $(BINARY_NAME)

$(OBJECTS) : $(SOURCES)
#	$(CC) -c -I/usr/share/verilator/include -Iobj_dir/ $(CPP_SOURCES) -o $@
	$(CC) -c -I/usr/share/verilator/include -Iobj_dir/ $(CPP_SOURCES)

verilated:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_TOP)

verilated_lib: verilated
	$(MAKE) --no-print-directory -C obj_dir/ -f Vaxis_fifo.mk

#	$(MAKE) -j 4 -C obj_dir -f Vaxis_fifo.mk

clean:
	rm -r obj_dir
