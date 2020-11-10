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
#include <numeric>
#include <verilated.h>
#include "Vaxis_padder.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

std::vector<std::vector<vluint8_t>> testPadder(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_padder> uut("padder.vcd", false);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);
	AXISSink<vluint8_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tdata = &uut.uut->axis_o_tdata});


	AXISSource<vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tdata = &uut.uut->axis_i_tdata},
		inData);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false || uut.getTime() == 10000 || inData.size() == outAxis.getTlastCount())
        {
            break;
        }
	}
	return outAxis.getData();
}

TEST_CASE("Test that padder pads", "[axis_padder]")
{
	std::vector<vluint8_t> testData = {0x0,0x1,0x2,0x3};
	std::vector<std::vector<vluint8_t>> outData = {testData};
	outData[0].resize(50);
	REQUIRE(testPadder({testData}) == outData);
}

TEST_CASE("Test that padder doesn't pad really long vector", "[axis_padder]")
{
	std::vector<vluint8_t> testData(100);
	std::iota(std::begin(testData), std::end(testData), 0); //Fill with 0,1,...

	std::vector<std::vector<vluint8_t>> outData = {testData};
	REQUIRE(testPadder({testData}) == outData);
}

TEST_CASE("Test that padder doesn't pad vector of size 50 (max size)", "[axis_padder]")
{
	std::vector<vluint8_t> testData(50);
	std::iota(std::begin(testData), std::end(testData), 0); //Fill with 0,1,...

	std::vector<std::vector<vluint8_t>> outData = {testData};
	REQUIRE(testPadder({testData}) == outData);
}
