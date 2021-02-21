add_library(network_object OBJECT
#        test_eth_crc.cpp
#        test_eth_framer.cpp
        test_ip_header_gen.cpp
        test_ip_checksum.cpp
        test_ip_deframer.cpp
        test_tcp_deframer.cpp
        test_arp_engine.cpp
        ../../../sim/network/TunTap.cpp
        )
target_link_libraries(network_object PUBLIC network_verilated)