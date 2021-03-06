//  Copyright (C) 2020 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vip_deframer_harness.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"

namespace {
    struct ret_data {
        uint8_t protocol;
        uint32_t src_ip;
        uint32_t dest_ip;
        uint16_t payload_length;
        std::vector<vluint8_t> payload;
    };

    auto testdeframer(std::vector<vluint8_t> packet, bool recordVcd = false) {
        VerilatedModel<Vip_deframer_harness> uut("ip_deframer.vcd", recordVcd);

        ClockGen clk(uut.getTime(), 1e-9, 100e6);

        SimplePacketSource<uint8_t> inAxisSource({packet});
        AXISSource<vluint32_t, vluint8_t> inAxis(&uut, &clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>
                {
                        .tready = &uut.uut->axis_i_tready,
                        .tvalid = &uut.uut->axis_i_tvalid,
                        .tlast = &uut.uut->axis_i_tlast,
                        .tkeep = &uut.uut->axis_i_tkeep,
                        .tdata = &uut.uut->axis_i_tdata
                }, &inAxisSource);

        SimplePacketSink<uint8_t> outAxisDataSink;
        SimplePacketSink<uint32_t> outAxisProtocolSink;
        SimplePacketSink<uint32_t> outAxisSrcIpSink;
        SimplePacketSink<uint32_t> outAxisDstIpSink;
        SimplePacketSink<uint32_t> outAxisLenBytesSink;

        AXISSink<vluint32_t, vluint8_t, vluint32_t, 4> outAxis(&uut, &clk, &uut.uut->sresetn,
                                                               AxisSignals<vluint32_t, vluint8_t, vluint32_t, 4>
                                                                       {
                                                                               .tready = &uut.uut->axis_o_tready,
                                                                               .tvalid = &uut.uut->axis_o_tvalid,
                                                                               .tlast = &uut.uut->axis_o_tlast,
                                                                               .tkeep = &uut.uut->axis_o_tkeep,
                                                                               .tdata = &uut.uut->axis_o_tdata,
                                                                               .tusers = {&uut.uut->axis_o_protocol,
                                                                                          &uut.uut->axis_o_src_ip,
                                                                                          &uut.uut->axis_o_dst_ip,
                                                                                          &uut.uut->axis_o_length_bytes}
                                                                       },
                                                                       &outAxisDataSink,
                                                               {
                                                                    &outAxisProtocolSink,
                                                                    &outAxisSrcIpSink,
                                                                    &outAxisDstIpSink,
                                                                    &outAxisLenBytesSink
                                                               });

        ResetGen resetGen(&uut, &clk, &uut.uut->sresetn, false);

        ClockBind clkDriver(clk, uut.uut->clk);
        uut.addClock(&clkDriver);

        while (true) {
            if (uut.eval() == false || uut.getTime() == 10000 || outAxisDataSink.getNumPackets() == 1) {
                break;
            }
        }

        // Check that we only have one packet out
        assert(outAxisDataSink.getNumPackets() == 1);
        assert(outAxisProtocolSink.getNumPackets() == 1);
        assert(outAxisSrcIpSink.getNumPackets() == 1);
        assert(outAxisDstIpSink.getNumPackets() == 1);
        assert(outAxisLenBytesSink.getNumPackets() == 1);

        // Check all beats are the same for the users (i.e. constant for whole packet)
        auto check_data_same = [](const auto &packet)
        {
            for (const auto &beat : packet.getData().at(0)) {
                assert(packet.getData().front().front() == beat);
            }
        };
        check_data_same(outAxisProtocolSink);
        check_data_same(outAxisSrcIpSink);
        check_data_same(outAxisDstIpSink);
        check_data_same(outAxisLenBytesSink);


        return ret_data{
            static_cast<uint8_t>(outAxisProtocolSink.getData().front().front()),
            outAxisSrcIpSink.getData().front().front(),
            outAxisDstIpSink.getData().front().front(),
            static_cast<uint16_t>(outAxisLenBytesSink.getData().front().front()),
            outAxisDataSink.getData().front()
        };
    }

    TEST_CASE("Test deframer with random UDP packet", "[ip_deframer]")
    {
        // This was captured off the wire using:
        // echo -n "Hello" | nc -u 192.168.0.35 2115 (from 192.168.0.37)
        std::vector<vluint8_t> packet =
                {0x45, 0x00, 0x00, 0x21, 0xe9, 0x37, 0x40, 0x00, 0x40, 0x11, 0xcf, 0xfb,
                 0xC0, 0xA8, 0x00, 0x25, 0xC0, 0xA8, 0x00, 0x23,
                 0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f};
        auto result = testdeframer(packet, true);
        REQUIRE(result.protocol == 0x11); //UDP
        REQUIRE(result.src_ip == 0xC0A80025); //192.168.0.37
        REQUIRE(result.dest_ip == 0xC0A80023); //192.168.0.23
        std::vector<uint8_t> expected_data(
                {0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
        REQUIRE(result.payload_length == expected_data.size()); // Payload + UDP header

        REQUIRE(result.payload == expected_data);
    }

    TEST_CASE("Test deframer with random UDP packet padded", "[ip_deframer]")
    {
        // This was captured off the wire using:
        // echo -n "Hello" | nc -u 192.168.0.35 2115 (from 192.168.0.37)
        std::vector<vluint8_t> packet =
                {0x45, 0x00, 0x00, 0x21, 0xe9, 0x37, 0x40, 0x00, 0x40, 0x11, 0xcf, 0xfb,
                 0xC0, 0xA8, 0x00, 0x25, 0xC0, 0xA8, 0x00, 0x23,
                 0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x0, 0x0, 0x0, 0x0, 0x0,
                 0x0, 0x0, 0x0} // Same as above, padded with bonus data, check it strips it
        ;
        auto result = testdeframer(packet, true);
        REQUIRE(result.protocol == 0x11); //UDP
        REQUIRE(result.src_ip == 0xC0A80025); //192.168.0.37
        REQUIRE(result.dest_ip == 0xC0A80023); //192.168.0.23
        std::vector<uint8_t> expected_data(
                {0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
        REQUIRE(result.payload_length == expected_data.size()); // Payload + UDP header

        // Pad because tkeep is not yet supported...
        expected_data.push_back(0);
        expected_data.push_back(0);
        expected_data.push_back(0);
        REQUIRE(result.payload == expected_data);
    }
}