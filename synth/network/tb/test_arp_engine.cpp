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

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"
#include "../../../sim/network/TunTap.hpp"


TEST_CASE("arp_engine: Test ARP engine responds to ARP requests", "[arp_engine]")
{
    VerilatedModel<Varp_engine_harness> uut("arp_engine.vcd", true);

    ClockGen clk(uut.getTime(), 1e-9, 100e6);

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

    std::system(std::string("ip addr add 10.0.0.100/8 dev "+tap.getName()).c_str());

}