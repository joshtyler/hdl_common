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
        file(APPEND ${FILE_NAME} "V${BASE_NAME}_${SUFFIX}, ")
    endforeach(SUFFIX)
    list(GET SUFFIX_LIST -1 LAST_SUFFIX)
    file(APPEND ${FILE_NAME} "V${BASE_NAME}_${LAST_SUFFIX}\n")

    # Close off the include guard
    file(APPEND ${FILE_NAME} "#endif //${INCLUDE_GUARD}\n")
endfunction()

function(verilate_multi_bytes BASE_NAME BYTES_LIST) # Follow expected arguments with all the arguments to pass to verilated
    foreach(bytes ${BYTES_LIST})
        verilate(${ARGN} PREFIX V${BASE_NAME}_${bytes} VERILATOR_ARGS "-GAXIS_BYTES=${bytes}")
    endforeach(bytes)
    write_verilated_header(${BASE_NAME} "${BYTES_LIST}")
endfunction()

add_library(network_verilated STATIC)
target_include_directories(network_verilated PUBLIC ${CMAKE_CURRENT_BINARY_DIR})
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES eth_crc.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES eth_framer.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES ip_header_gen.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES rmii_to_axis.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES udp_header_gen.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES ip_deframer.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES tb/ip_deframer_harness.sv TRACE)
verilate(network_verilated VERILATOR_ARGS "-I../" "-I../axis/" SOURCES tb/tcp_deframer_harness.sv TRACE)

set(IP_CHECKSUM_BYTES_LIST 2 4)
verilate_multi_bytes(ip_checksum "${IP_CHECKSUM_BYTES_LIST}" network_verilated VERILATOR_ARGS "-I../" SOURCES ip_checksum.sv TRACE)


add_subdirectory(tb)