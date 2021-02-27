//  Copyright (C) 2021 Joshua Tyler
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
#include "Varp_engine_harness.h"
#include "Varp_engine_harness_with_mac.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/network/GMIISource.hpp"
#include "../../../sim/network/GMIISink.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"
#include "../../../sim/network/TunTap.hpp"


TEST_CASE("arp_engine: Test ARP engine responds to ARP requests", "[arp_engine]")
{
    VerilatedModel<Varp_engine_harness> uut("arp_engine.vcd", true);

    ClockGen clk(uut.getTime(), 1e-9, 100e6);
    ResetGen resetGen(clk,uut.uut->sresetn, false);

    // If you want to look at the data manually, run ip tuntap add name tap0 mode tap
    // Then pass "tap0" as the argument to this constructor
    Tap tap;

    AXISSource<vluint32_t, vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>
            {
                    .tready = &uut.uut->axis_i_tready,
                    .tvalid = &uut.uut->axis_i_tvalid,
                    .tlast = &uut.uut->axis_i_tlast,
                    .tkeep = &uut.uut->axis_i_tkeep,
                    .tdata = &uut.uut->axis_i_tdata
            }, &tap);

    AXISSink<vluint32_t, vluint8_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>
    {
        .tready = &uut.uut->axis_o_tready,
        .tvalid = &uut.uut->axis_o_tvalid,
        .tlast = &uut.uut->axis_o_tlast,
        .tkeep = &uut.uut->axis_o_tkeep,
        .tdata = &uut.uut->axis_o_tdata
    }, &tap);

    uut.addPeripheral(&resetGen);
    uut.addPeripheral(&inAxis);
    uut.addPeripheral(&outAxis);
    ClockBind clkDriver(clk,uut.uut->clk);
    uut.addClock(&clkDriver);

    std::system(std::string("ip addr add 10.0.0.100/8 dev "+tap.getName()).c_str());
    std::system(std::string("ip link set "+tap.getName()+" up").c_str());
    FILE * arping_file;

    while(true)
    {
        if (uut.eval() == false)
        {
            std::cerr << "uut.eval() failed!\n";
            break;
        }

        if(uut.getTime() == 50000)
        {
            arping_file = popen("arping 10.0.0.110 -c 5", "r");
        }

        if (uut.getTime() == 100000)
        {
            std::cerr << "Timeout\n";
            break;
        }
    }

    int ret = pclose(arping_file);

    REQUIRE(ret == 0);
}

TEST_CASE("arp_engine: Test ARP engine responds to ARP requests (with ethernet MAC in the loop too", "[arp_engine]")
{
    VerilatedModel<Varp_engine_harness_with_mac> uut("arp_engine_with_mac.vcd", true);

    ClockGen clketh(uut.getTime(), 1e-9, 125e6);
    ClockGen clkuser(uut.getTime(), 1e-9, 50e6);

    // If you want to look at the data manually, run ip tuntap add name tap0 mode tap
    // Then pass "tap0"end as the argument to this constructor
    Tap tap("tap0");

    GMIISource src(&clketh, &uut.uut->eth_rxd, &uut.uut->eth_rxdv, &uut.uut->eth_rxer, &tap);

    // Currently we assume that the UUT outputs data on the same clock as rxclk
    // But this is not required(!)
    GMIISink sink(&clketh, &uut.uut->eth_txd, &uut.uut->eth_txen, &uut.uut->eth_txer, &tap);

    uut.addPeripheral(&src);
    uut.addPeripheral(&sink);
    ClockBind clkDriverUser(clkuser,uut.uut->clk);
    ClockBind clkDriverEth(clketh, uut.uut->eth_rxclk);
    uut.addClock(&clkDriverUser);
    uut.addClock(&clkDriverEth);

    std::system(std::string("ip addr add 10.0.0.100/8 dev "+tap.getName()).c_str());
    std::system(std::string("ip link set "+tap.getName()+" up").c_str());
    auto arping_file = popen("arping 10.0.0.110 -c 5", "r");

    while(true)
    {
        if (uut.eval() == false)
        {
            std::cerr << "uut.eval() failed!\n";
            break;
        }

        if (uut.getTime() == 1000000)
        {
            std::cerr << "Timeout\n";
            break;
        }
    }

    int ret = pclose(arping_file);

    REQUIRE(ret == 0);
}