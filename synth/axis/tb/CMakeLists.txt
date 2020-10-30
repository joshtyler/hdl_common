add_library(axis_object OBJECT
        test_axis_broadcaster.cpp
        test_axis_fifo.cpp
        test_axis_packet_fifo.cpp
        test_axis_packet_fifo_async.cpp
        test_axis_padder.cpp
        test_axis_register.cpp
        test_axis_register.cpp
        test_axis_round_robin.cpp
        test_axis_width_converter.cpp
        )
target_link_libraries(axis_object PUBLIC axis_verilated)