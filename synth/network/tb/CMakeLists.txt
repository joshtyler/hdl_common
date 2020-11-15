add_library(network_object OBJECT
#        test_eth_crc.cpp
#        test_eth_framer.cpp
        test_ip_header_gen.cpp
        test_udp_checksum.cpp
        test_ip_deframer.cpp)
target_link_libraries(network_object PUBLIC network_verilated)