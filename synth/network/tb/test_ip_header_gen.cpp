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
#include "Vip_header_gen.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

auto testip(uint64_t src_ip, uint64_t dest_ip, uint8_t protocol, std::vector<std::vector<vluint8_t>> len, std::string vcdName="foo.vcd", bool recordVcd=false)
{
	VerilatedModel<Vip_header_gen> uut(vcdName, recordVcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	uut.uut->src_ip = src_ip;
	uut.uut->dest_ip = dest_ip;
	uut.uut->protocol = protocol;

	AXISSource<vluint16_t> lenAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint16_t>{.tready = &uut.uut->payload_length_axis_tready, .tvalid = &uut.uut->payload_length_axis_tvalid, .tlast = &uut.uut->payload_length_axis_tlast, .tdata = &uut.uut->payload_length_axis_tdata}, len);


	AXISSink<vluint8_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tdata = &uut.uut->axis_o_tdata});


	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&lenAxis);
	uut.addPeripheral(&outAxis);
	uut.addPeripheral(&resetGen);
	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false || uut.getTime() == 10000 || len.size() == outAxis.getTlastCount())
        {
            break;
        }
	}
	return outAxis.getData();
}

TEST_CASE("Test with random UDP packet", "[ip_header_gen]")
{
	// This was captured off the wire using:
	// echo -n "Hello" | nc -u 192.168.0.35 2115 (from 192.168.0.31)
	std::vector<vluint8_t> outData =
		{0x45,0x00, 0x00, 0x21, 0xA8, 0x6C, 0x40, 0x00, 0x40, 0x11, 0x10, 0xCD,
		 0xC0, 0xA8, 0x00, 0x1F, 0xC0, 0xA8, 0x00, 0x23}
	;
	uint64_t src_ip = 0xC0A8001F; //192.168.0.31
	uint64_t dest_ip = 0xC0A80023; //192.168.0.35
	uint8_t protocol = 0x11; //UDP
	auto result = testip(src_ip, dest_ip, protocol, {{13,0}}, "ip.vcd",true);
	REQUIRE(outData == result.at(0));
}
