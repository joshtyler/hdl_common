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
#include "Vaxis_width_converter_1i_1o.h"
#include "Vaxis_width_converter_1i_2o.h"
#include "Vaxis_width_converter_2i_1o.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"
#include "../../../sim/other/PacketSourceSink.hpp"

template <class model_t, class data_in_t, class data_out_t> auto testWidthConverter(std::vector<std::vector<uint8_t>> inData, std::string vcdName="foo.vcd", bool recordVcd=false)
{
	VerilatedModel<model_t> uut(vcdName, recordVcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

    SimplePacketSource<uint8_t> inAxisSource(inData);
	AXISSource<data_in_t, vluint8_t> inAxis(&clk, &uut.uut->sresetn, AxisSignals<data_in_t, vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tkeep = &uut.uut->axis_i_tkeep, .tdata = &uut.uut->axis_i_tdata}, &inAxisSource);

    SimplePacketSink<uint8_t> outAxisSink;
	AXISSink<data_out_t, vluint8_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<data_out_t, vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tkeep = &uut.uut->axis_o_tkeep, .tdata = &uut.uut->axis_o_tdata}, &outAxisSink);


	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false)
        {
	        std::cout << "uut.eval() failed" << std::endl;
            break;
        }

        if(uut.getTime() == 10000)
        {
            std::cout << "Timeout" << std::endl;
            break;
        }

        if(inData.size() == outAxisSink.getNumPackets())
        {
            std::cout << "Got all the data" << std::endl;
            break;
        }
	}
    return outAxisSink.getData();
}

TEST_CASE("width_converter: Test width converter pass through", "[axis_width_converter]")
{
	std::vector<std::vector<vluint8_t>> testData = {{0x0,0x1,0x2,0x3}};
	auto result = testWidthConverter<Vaxis_width_converter_1i_1o,vluint8_t, vluint8_t>(testData);
	REQUIRE(testData == result);
}

TEST_CASE("width_converter: Test converting wide to narrow", "[axis_width_converter]")
{
	const std::vector<std::vector<vluint8_t>> data = {{0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7}};
	auto result = testWidthConverter<Vaxis_width_converter_2i_1o,vluint16_t, vluint8_t>(data, "width_converter_wide_to_narrow.vcd", true);
	REQUIRE(data == result);
}

TEST_CASE("width_converter: Test converting narrow to wide", "[axis_width_converter]")
{
    const std::vector<std::vector<vluint8_t>> data = {{0x0,0x1,0x2,0x3,0x4,0x5,0x6,0x7}};
	auto result = testWidthConverter<Vaxis_width_converter_1i_2o,vluint8_t, vluint16_t>(data, "width_converter_narrow_to_wide.vcd", false);
	REQUIRE(data == result);
}

TEST_CASE("width_converter: Test converting narrow to wide, but assering tkeep early", "[axis_width_converter]")
{
    const std::vector<std::vector<vluint8_t>> data = {{0x0,0x1,0x2,0x3,0x4,0x5,0x6}};
	auto result = testWidthConverter<Vaxis_width_converter_1i_2o,vluint8_t, vluint16_t>(data, "width_converter_narrow_to_wide_early.vcd", false);
	// No need to pad since tkeep is supported
	REQUIRE(data == result);
}
