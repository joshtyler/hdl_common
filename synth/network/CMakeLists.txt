add_library(network_verilated STATIC)
verilate(network_verilated SOURCES eth_crc.sv TRACE)
verilate(network_verilated SOURCES eth_framer.sv INCLUDE_DIRS ../axis TRACE)
verilate(network_verilated SOURCES ip_header_gen.sv INCLUDE_DIRS ../axis  TRACE)
verilate(network_verilated SOURCES rmii_to_axis.sv TRACE)
verilate(network_verilated SOURCES udp_checksum.sv INCLUDE_DIRS ../axis TRACE)
verilate(network_verilated SOURCES udp_header_gen.sv INCLUDE_DIRS ../axis  TRACE)

add_subdirectory(tb)