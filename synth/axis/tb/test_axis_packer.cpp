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
#include "Vaxis_packer.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/SimplePacketSource.hpp"

std::vector<std::vector<vluint8_t>> testPacker(std::vector<std::vector<vluint8_t>> inData)
{
	VerilatedModel<Vaxis_packer> uut("packer.vcd", true);
	ClockGen clk(uut.getTime(), 1e-9, 100e6);

    AXISSinkConfig sinkConfig;
    sinkConfig.packed = false;

	AXISSink<vluint32_t, vluint8_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tkeep = &uut.uut->axis_o_tkeep, .tdata = &uut.uut->axis_o_tdata}, sinkConfig);

    AXISSourceConfig sourceConfig;
    sourceConfig.packed = true;
    SimplePacketSource<uint8_t> inAxisSource(inData);
	AXISSource<vluint32_t, vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tkeep = &uut.uut->axis_i_tkeep, .tdata = &uut.uut->axis_i_tdata}, &inAxisSource, std::array<PacketSource<vluint32_t>*, 0>{}, sourceConfig);

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false)
        {
            std::cerr << "Eval false" << std::endl;
            break;
        }

        if(uut.getTime() == 500000)
        {
            std::cerr << "Timeout (" << inData.size() << ", " << outAxis.getTlastCount() << ')' << std::endl;
            break;
        }

        if(inData.size() == outAxis.getTlastCount())
        {
            break;
        }
	}
	return outAxis.getData();
}

TEST_CASE("Test packer operation", "[axis_packer]")
{
    std::mt19937 gen(1);
    std::uniform_int_distribution<> distrib(1, 255);
    std::vector<std::vector<vluint8_t>> testData;
    for(int i=0; i<30; i++)
    {
        std::vector<vluint8_t> vec(distrib(gen));
        for(size_t i=0; i<vec.size(); i++) {
            vec.at(i) = i;
        }
        testData.push_back(vec);
        REQUIRE(testPacker(testData) == testData);
    }

}
