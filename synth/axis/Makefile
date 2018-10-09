VERILATOR = verilator
#VERILATOR_FLAGS = --trace --cc --exe -CFLAGS '-Wall -Wextra -g -fno-stack-protector'
VERILATOR_FLAGS = -I../other --trace --cc --exe -CFLAGS '-Wall -Wextra -g '

VERILOG_TOP = axis_fifo.sv

CC = g++
CPP_SOURCES = tb/test_axis_fifo.cpp
BINARY_NAME = test_axis_fifo

default : sim

sim : verilated
	$(CC) -I/usr/share/verilator/include -Iobj_dir/ obj_dir/Vaxis_fifo__ALLcls.o obj_dir/Vaxis_fifo__ALLsup.o obj_dir/verilated.o obj_dir/verilated_vcd_c.o $(CPP_SOURCES)  -o test_eth_crc

verilated:
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILOG_TOP)

#	$(MAKE) -j 4 -C obj_dir -f Vaxis_fifo.mk

clean:
	rm -r obj_dir
