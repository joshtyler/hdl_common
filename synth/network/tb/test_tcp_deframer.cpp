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
        AXISSource<vluint32_t, vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>
                {
                        .tready = &uut.uut->axis_i_tready,
                        .tvalid = &uut.uut->axis_i_tvalid,
                        .tlast = &uut.uut->axis_i_tlast,
                        .tkeep = &uut.uut->axis_i_tkeep,
                        .tdata = &uut.uut->axis_i_tdata
                }, {packet});

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
                                                                        });

        ResetGen resetGen(clk, uut.uut->sresetn, false);

        uut.addPeripheral(&inAxis);
        uut.addPeripheral(&outAxis);
        uut.addPeripheral(&resetGen);
        ClockBind clkDriver(clk, uut.uut->clk);
        uut.addClock(&clkDriver);

        while (true) {
            if (uut.eval() == false || uut.getTime() == 10000 || outAxis.getTlastCount() == 1) {
                break;
            }
        }

        auto data = outAxis.getData();
        auto users = outAxis.getUsers();

        // Check that we only have one packet out
        assert(users.size() == 1);
        assert(data.size() == 1);

        // Check all beats are the same for the users (i.e. constant for whole packet)
        for (const auto &beat : users) {
            assert(users.front() == beat);
        }

        auto first_users = users.front().front();
        return ret_data
                {
                        static_cast<uint16_t>(first_users.at(0)),
                        static_cast<uint16_t>( first_users.at(1)),
                        static_cast<uint16_t>(first_users.at(2)),
                        first_users.at(3),
                        first_users.at(4),
                        static_cast<bool>(first_users.at(5)),
                        static_cast<bool>(first_users.at(6)),
                        static_cast<bool>(first_users.at(7)),
                        static_cast<bool>(first_users.at(8)),
                        static_cast<uint16_t>(first_users.at(9)),
                        data.front()
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