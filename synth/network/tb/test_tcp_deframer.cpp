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
#include "Vtcp_deframer_harness.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"

namespace {
    struct ret_data {
        uint16_t length_bytes;
        uint16_t src_port;
        uint16_t dst_port;
        uint32_t seq_num;
        uint32_t ack_num;
        bool ack;
        bool rst;
        bool syn;
        bool fin;
        uint16_t window_size;
        std::vector<vluint8_t> payload;
    };

    auto testdeframer(std::vector<vluint8_t> packet, bool recordVcd = false) {
        VerilatedModel<Vtcp_deframer_harness> uut("tcp_deframer.vcd", recordVcd);

        ClockGen clk(uut.getTime(), 1e-9, 100e6);

        uut.uut->axis_i_length_bytes = packet.size(); // Hack because AXISSource doesn't support user
        SimplePacketSource<uint8_t> inAxisSource({packet});
        AXISSource<vluint32_t, vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>
                {
                        .tready = &uut.uut->axis_i_tready,
                        .tvalid = &uut.uut->axis_i_tvalid,
                        .tlast = &uut.uut->axis_i_tlast,
                        .tkeep = &uut.uut->axis_i_tkeep,
                        .tdata = &uut.uut->axis_i_tdata
                }, &inAxisSource);

        SimplePacketSink<uint8_t> outAxisDataSink;
        SimplePacketSink<uint32_t> outAxisLengthSink;
        SimplePacketSink<uint32_t> outAxisSrcPortSink;
        SimplePacketSink<uint32_t> outAxisDstPortSink;
        SimplePacketSink<uint32_t> outAxisSeqNumSink;
        SimplePacketSink<uint32_t> outAxisAckNumSink;
        SimplePacketSink<uint32_t> outAxisAckSink;
        SimplePacketSink<uint32_t> outAxisRstSink;
        SimplePacketSink<uint32_t> outAxisSynSink;
        SimplePacketSink<uint32_t> outAxisFinSink;
        SimplePacketSink<uint32_t> outAxisWindowSink;
        AXISSink<vluint32_t, vluint8_t, vluint32_t, 10> outAxis(&clk, &uut.uut->sresetn,
                                                                AxisSignals<vluint32_t, vluint8_t, vluint32_t, 10>
                                                                        {
                                                                                .tready = &uut.uut->axis_o_tready,
                                                                                .tvalid = &uut.uut->axis_o_tvalid,
                                                                                .tlast = &uut.uut->axis_o_tlast,
                                                                                .tkeep = &uut.uut->axis_o_tkeep,
                                                                                .tdata = &uut.uut->axis_o_tdata,
                                                                                .tusers =
                                                                                        {
                                                                                                &uut.uut->axis_o_length_bytes,
                                                                                                &uut.uut->axis_o_src_port,
                                                                                                &uut.uut->axis_o_dst_port,
                                                                                                &uut.uut->axis_o_seq_num,
                                                                                                &uut.uut->axis_o_ack_num,
                                                                                                &uut.uut->axis_o_ack,
                                                                                                &uut.uut->axis_o_rst,
                                                                                                &uut.uut->axis_o_syn,
                                                                                                &uut.uut->axis_o_fin,
                                                                                                &uut.uut->axis_o_window_size
                                                                                        }
                                                                        },
                                                                        &outAxisDataSink,
                                                                {
                                                                    &outAxisLengthSink,
                                                                    &outAxisSrcPortSink,
                                                                    &outAxisDstPortSink,
                                                                    &outAxisSeqNumSink,
                                                                    &outAxisAckNumSink,
                                                                    &outAxisAckSink,
                                                                    &outAxisRstSink,
                                                                    &outAxisSynSink,
                                                                    &outAxisFinSink,
                                                                    &outAxisWindowSink
                                                                });

        ResetGen resetGen(clk, uut.uut->sresetn, false);

        uut.addPeripheral(&inAxis);
        uut.addPeripheral(&outAxis);
        uut.addPeripheral(&resetGen);
        ClockBind clkDriver(clk, uut.uut->clk);
        uut.addClock(&clkDriver);

        while (true) {
            if (uut.eval() == false || uut.getTime() == 10000 || outAxisDataSink.getNumPackets() == 1) {
                break;
            }
        }


        // Check that we only have one packet out
        assert(outAxisDataSink.getNumPackets() == 1);
        assert(outAxisLengthSink.getNumPackets() == 1);
        assert(outAxisSrcPortSink.getNumPackets() == 1);
        assert(outAxisDstPortSink.getNumPackets() == 1);
        assert(outAxisSeqNumSink.getNumPackets() == 1);
        assert(outAxisAckNumSink.getNumPackets() == 1);
        assert(outAxisAckSink.getNumPackets() == 1);
        assert(outAxisRstSink.getNumPackets() == 1);
        assert(outAxisSynSink.getNumPackets() == 1);
        assert(outAxisFinSink.getNumPackets() == 1);
        assert(outAxisWindowSink.getNumPackets() == 1);

        // Check all beats are the same for the users (i.e. constant for whole packet)
        auto check_data_same = [](const auto &packet)
        {
            for (const auto &beat : packet.getData().at(0)) {
                assert(packet.getData().front().front() == beat);
            }
        };
        check_data_same(outAxisLengthSink);
        check_data_same(outAxisSrcPortSink);
        check_data_same(outAxisDstPortSink);
        check_data_same(outAxisSeqNumSink);
        check_data_same(outAxisAckNumSink);
        check_data_same(outAxisAckSink);
        check_data_same(outAxisRstSink);
        check_data_same(outAxisSynSink);
        check_data_same(outAxisFinSink);
        check_data_same(outAxisWindowSink);

        return ret_data
                {
                        static_cast<uint16_t>(outAxisLengthSink.getData().front().front()),
                        static_cast<uint16_t>(outAxisSrcPortSink.getData().front().front()),
                        static_cast<uint16_t>(outAxisDstPortSink.getData().front().front()),
                        outAxisSeqNumSink.getData().front().front(),
                        outAxisAckNumSink.getData().front().front(),
                        static_cast<bool>(outAxisAckSink.getData().front().front()),
                        static_cast<bool>(outAxisRstSink.getData().front().front()),
                        static_cast<bool>(outAxisSynSink.getData().front().front()),
                        static_cast<bool>(outAxisFinSink.getData().front().front()),
                        static_cast<uint16_t>(outAxisWindowSink.getData().front().front()),
                        outAxisDataSink.getData().front()
                };
    }

    TEST_CASE("tcp_deframer: Test deframer with random TCP packet", "[tcp_deframer]")
    {
        // This was captured off the wire
        std::vector<vluint8_t> packet = {0x9a, 0x34, 0x23, 0x28, 0xdd, 0x6c, 0x7a, 0x23, 0x03, 0x61, 0xc4, 0x17, 0x80,
                                         0x18, 0x02, 0x00, 0xfe, 0x2e, 0x00, 0x00, 0x01, 0x01, 0x08, 0x0a, 0x1c, 0x13,
                                         0xc6, 0xb2, 0x1c, 0x13, 0xc6, 0xb2, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x0a};
        auto result = testdeframer(packet, true);
        std::vector<uint8_t> expected_data({0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x0a});

        REQUIRE(result.length_bytes == expected_data.size()); //UDP
        REQUIRE(result.src_port == 39476);
        REQUIRE(result.dst_port == 9000);
        REQUIRE(result.seq_num == 3714873891);
        REQUIRE(result.ack_num == 56738839);
        REQUIRE(result.ack == true);
        REQUIRE(result.rst == false);
        REQUIRE(result.syn == false);
        REQUIRE(result.fin == false);
        REQUIRE(result.window_size == 512);
        REQUIRE(result.payload == expected_data);
    }
}