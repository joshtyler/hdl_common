//  Copyright (C) 2019 Joshua Tyler
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
#include "Vaxis_round_robin_harness.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

auto testAxisRoundRobin(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_round_robin_harness> uut("round_robin.vcd",false);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	AXISSource<vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tkeep = &uut.uut->axis_i_tkeep, .tdata = &uut.uut->axis_i_tdata},
		inData);

	AXISSink<vluint8_t> outAxis1(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_o1_tready, .tvalid = &uut.uut->axis_o1_tvalid, .tlast = &uut.uut->axis_o1_tlast, .tkeep = &uut.uut->axis_o1_tkeep, .tdata = &uut.uut->axis_o1_tdata});

	AXISSink<vluint8_t> outAxis2(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_o2_tready, .tvalid = &uut.uut->axis_o2_tvalid, .tlast = &uut.uut->axis_o2_tlast, .tkeep = &uut.uut->axis_o2_tkeep, .tdata = &uut.uut->axis_o2_tdata});


	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&outAxis1);
	uut.addPeripheral(&outAxis2);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false || uut.getTime() == 10000 || (inData.size() == outAxis1.getTlastCount() && inData.size() == outAxis2.getTlastCount()))
        {
            break;
        }
	}
	//return outAxis.getData();
	std::array<std::vector<std::vector<vluint8_t>>, 2> outArr;
	outArr[0] = outAxis1.getData();
	outArr[1] = outAxis2.getData();
	return outArr;
}

TEST_CASE("Test behaviour of round robin distributor", "[axis_round_robin]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3},{0x4,0x5,0x6,0x7},{0x8,0x9},{0xA,0xB}};
	std::vector<std::vector<vluint8_t>> outData1 = {{0x0,0x1,0x2,0x3},{0x8,0x9}};
	std::vector<std::vector<vluint8_t>> outData2 = {{0x4,0x5,0x6,0x7},{0xA,0xB}};
	std::array<std::vector<std::vector<vluint8_t>>,2> outData = {outData1, outData2};
	auto result = testAxisRoundRobin(testData);
	REQUIRE( outData == result);
}
