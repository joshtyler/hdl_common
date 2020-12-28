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

struct ret_data
{
    uint8_t protocol;
    uint32_t src_ip;
    uint32_t dest_ip;
    uint16_t payload_length;
    std::vector<vluint8_t> payload;
};

auto testdeframer(std::vector<vluint8_t> packet, bool recordVcd=false)
{
    VerilatedModel<Vip_deframer_harness> uut("ip_deframer.vcd", recordVcd);

    ClockGen clk(uut.getTime(), 1e-9, 100e6);

    AXISSource<vluint32_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t>
        {
            .tready = &uut.uut->axis_i_tready,
            .tvalid = &uut.uut->axis_i_tvalid,
            .tlast = &uut.uut->axis_i_tlast,
            .tdata = &uut.uut->axis_i_tdata
        }, {packet});

    AXISSink<vluint32_t, vluint8_t, vluint32_t, 4> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t, vluint32_t, 4>
            {
                    .tready = &uut.uut->axis_o_tready,
                    .tvalid = &uut.uut->axis_o_tvalid,
                    .tlast = &uut.uut->axis_o_tlast,
                    .tdata = &uut.uut->axis_o_tdata,
                    .tusers = {&uut.uut->axis_o_protocol, &uut.uut->axis_o_src_ip, &uut.uut->axis_o_dst_ip, &uut.uut->axis_o_length_bytes}
            });

    ResetGen resetGen(clk,uut.uut->sresetn, false);

    uut.addPeripheral(&inAxis);
    uut.addPeripheral(&outAxis);
    uut.addPeripheral(&resetGen);
    ClockBind clkDriver(clk,uut.uut->clk);
    uut.addClock(&clkDriver);

    while(true)
    {
        if(uut.eval() == false || uut.getTime() == 10000 || outAxis.getTlastCount() == 1)
        {
            break;
        }
    }

    auto data = outAxis.getData();
    auto users = outAxis.getUsers();

    // Check that we only have one packet out
    assert(users.size() == 1);
    assert(data.size() == 1);

    // Check all beats are the same for the users (i.e. constant for whole packet)
    for(const auto& beat : users)
    {
        assert(users.front() == beat);
    }

    auto first_users = users.front().front();
    return ret_data{ static_cast<uint8_t>(first_users.at(0)), first_users.at(1), first_users.at(2), static_cast<uint16_t>(first_users.at(3)), data.front()};
}

TEST_CASE("Test deframer with random UDP packet", "[ip_deframer]")
{
    // This was captured off the wire using:
    // echo -n "Hello" | nc -u 192.168.0.35 2115 (from 192.168.0.37)
    std::vector<vluint8_t> packet =
            {0x45,0x00, 0x00, 0x21, 0xe9, 0x37, 0x40, 0x00, 0x40, 0x11, 0xcf, 0xfb,
             0xC0, 0xA8, 0x00, 0x25, 0xC0, 0xA8, 0x00, 0x23,
             0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f}
    ;
    auto result = testdeframer(packet, true);
    REQUIRE(result.protocol == 0x11); //UDP
    REQUIRE(result.src_ip == 0xC0A80025); //192.168.0.37
    REQUIRE(result.dest_ip == 0xC0A80023); //192.168.0.23
    std::vector<uint8_t> expected_data({0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
    REQUIRE(result.payload_length == expected_data.size()); // Payload + UDP header

    // Pad because tkeep is not yet supported...
    expected_data.push_back(0);
    expected_data.push_back(0);
    expected_data.push_back(0);
    REQUIRE(result.payload == expected_data);
}

TEST_CASE("Test deframer with random UDP packet padded", "[ip_deframer]")
{
    // This was captured off the wire using:
    // echo -n "Hello" | nc -u 192.168.0.35 2115 (from 192.168.0.37)
    std::vector<vluint8_t> packet =
            {0x45,0x00, 0x00, 0x21, 0xe9, 0x37, 0x40, 0x00, 0x40, 0x11, 0xcf, 0xfb,
             0xC0, 0xA8, 0x00, 0x25, 0xC0, 0xA8, 0x00, 0x23,
             0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0} // Same as above, padded with bonus data, check it strips it
    ;
    auto result = testdeframer(packet, true);
    REQUIRE(result.protocol == 0x11); //UDP
    REQUIRE(result.src_ip == 0xC0A80025); //192.168.0.37
    REQUIRE(result.dest_ip == 0xC0A80023); //192.168.0.23
    std::vector<uint8_t> expected_data({0xDC, 0x9B, 0x08, 0x43, 0x00, 0x0d, 0x81, 0xb7, 0x48, 0x65, 0x6c, 0x6c, 0x6f});
    REQUIRE(result.payload_length == expected_data.size()); // Payload + UDP header

    // Pad because tkeep is not yet supported...
    expected_data.push_back(0);
    expected_data.push_back(0);
    expected_data.push_back(0);
    REQUIRE(result.payload == expected_data);
}