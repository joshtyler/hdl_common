//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

// Simple testbench that just treats the async fifo as a sync fifo for now

#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vaxis_packet_fifo_async.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"

std::vector<std::vector<vluint8_t>> testPacketFifoAsync(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_packet_fifo_async> uut("packet_fifo_async.vcd", true);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);
    SimplePacketSink<uint8_t> outAxisSink;
	AXISSink<vluint8_t> outAxis(&uut, &clk, &uut.uut->i_sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tkeep = &uut.uut->axis_o_tkeep, .tdata = &uut.uut->axis_o_tdata}, &outAxisSink);

    SimplePacketSource<uint8_t> inAxisSource(inData);
	AXISSource<vluint8_t> inAxis(&uut, &clk, &uut.uut->o_sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tkeep = &uut.uut->axis_i_tkeep, .tdata = &uut.uut->axis_i_tdata},
		&inAxisSource);

	ResetGen i_resetGen(&uut, clk,uut.uut->i_sresetn, false);
	ResetGen o_resetGen(&uut, clk,uut.uut->o_sresetn, false);

	ClockBind i_clkDriver(clk,uut.uut->i_clk);
	ClockBind o_clkDriver(clk,uut.uut->o_clk);
	uut.addClock(&i_clkDriver);
	uut.addClock(&o_clkDriver);

	while(true)
	{
        if(uut.eval() == false || uut.getTime() == 10000 || inData.size() == outAxisSink.getNumPackets())
        {
            break;
        }
	}
	return outAxisSink.getData();
}

TEST_CASE("Test data comes out of async packet FIFO", "[axis_packet_fifo_async]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	REQUIRE(testPacketFifoAsync(testData) == testData);
}
