# Write out a header to let us use verilated classes in a generic way
function(write_verilated_header BASE_NAME SUFFIX_LIST)
    # Setup vars
    set(FILE_NAME ${CMAKE_CURRENT_BINARY_DIR}/${BASE_NAME}_verilated.h)
    string(TOUPPER ${BASE_NAME} BASE_NAME_UPPER)
    set(INCLUDE_GUARD ${BASE_NAME_UPPER}_H)

    # Delete file from last configure
    file(REMOVE ${FILE_NAME})

    # Add some include guards
    file(APPEND ${FILE_NAME} "#ifndef ${INCLUDE_GUARD}\n")
    file(APPEND ${FILE_NAME} "#define ${INCLUDE_GUARD}\n")

    # Include each generated header
    foreach(SUFFIX ${SUFFIX_LIST})
        file(APPEND ${FILE_NAME} "#include \"V${BASE_NAME}_${SUFFIX}.h\"\n")
    endforeach(SUFFIX)
    file(APPEND ${FILE_NAME} "\n")

    # Add a define for the list of generated classes
    file(APPEND ${FILE_NAME} "#define ${BASE_NAME_UPPER}_VERILATED_CLASSES ")
    list(LENGTH SUFFIX_LIST SUFFIX_LIST_END)
    math(EXPR SUFFIX_LIST_END "${SUFFIX_LIST_END}-1")
    list(SUBLIST SUFFIX_LIST 0 ${SUFFIX_LIST_END} SUFFIX_LIST_WITHOUT_END)
    foreach(SUFFIX ${SUFFIX_LIST_WITHOUT_END})
        file(APPEND ${FILE_NAME} "Vudp_checksum_${SUFFIX}, ")
    endforeach(SUFFIX)
    list(GET SUFFIX_LIST -1 LAST_SUFFIX)
    file(APPEND ${FILE_NAME} "Vudp_checksum_${LAST_SUFFIX}\n")

    # Close off the include guard
    file(APPEND ${FILE_NAME} "#endif //${INCLUDE_GUARD}\n")
endfunction()

add_library(network_verilated STATIC)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES eth_crc.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES eth_framer.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES ip_header_gen.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES rmii_to_axis.sv TRACE)

set(BYTES_LIST 2 4)
foreach(bytes ${BYTES_LIST})
    verilate(network_verilated VERILATOR_ARGS "-I../" SOURCES udp_checksum.sv PREFIX Vudp_checksum_${bytes} TRACE VERILATOR_ARGS "-GAXIS_BYTES=${bytes}")
endforeach(bytes)

write_verilated_header(udp_checksum "${BYTES_LIST}")
include_directories(${CMAKE_CURRENT_BINARY_DIR})

verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES udp_header_gen.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES ip_deframer.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES tb/ip_deframer_harness.sv TRACE)

add_subdirectory(tb)