add_library(axis_verilated STATIC)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_broadcaster.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_counter.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" "-I../other/" SOURCES axis_error_filter_async.sv  TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_fifo.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_gater.sv  TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_joiner.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_packet_fifo.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" "-I../other/" SOURCES axis_packet_fifo_async.sv  TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_padder.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_register.sv  TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_round_robin.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_spacer.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_spi_bridge.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_switch.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_width_converter.sv PREFIX Vaxis_width_converter_1i_1o TRACE VERILATOR_ARGS "-GAXIS_I_BYTES=1" "-GAXIS_O_BYTES=1")
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_width_converter.sv PREFIX Vaxis_width_converter_1i_2o TRACE VERILATOR_ARGS "-GAXIS_I_BYTES=1" "-GAXIS_O_BYTES=2")
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_width_converter.sv PREFIX Vaxis_width_converter_2i_1o TRACE VERILATOR_ARGS "-GAXIS_I_BYTES=2" "-GAXIS_O_BYTES=1")
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES rom_to_axis.sv  TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES vector_to_axis.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES axis_packer.sv TRACE)

verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES tb/axis_broadcaster_harness.sv TRACE)
verilate(axis_verilated VERILATOR_ARGS "-I../" SOURCES tb/axis_round_robin_harness.sv TRACE)

add_subdirectory(tb)