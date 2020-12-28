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
#include "ip_checksum_verilated.h"

#include "../../../sim/verilator/VerilatedModel.hpp"
#include "../../../sim/other/ResetGen.hpp"
#include "../../../sim/other/ClockGen.hpp"
#include "../../../sim/axis/AXISSink.hpp"
#include "../../../sim/axis/AXISSource.hpp"

//#define __LITTLE_ENDIAN
// Begin copied and pasted from linux/lib/checksum.c
static inline unsigned short from32to16(unsigned int x)
{
	/* add up 16-bit and 16-bit for 16+c bit */
	x = (x & 0xffff) + (x >> 16);
	/* add up carry.. */
	x = (x & 0xffff) + (x >> 16);
	return x;
}

static unsigned int do_csum(const unsigned char *buff, int len)
{
	int odd;
	unsigned int result = 0;

	if (len <= 0)
		goto out;
	odd = 1 & (unsigned long) buff;
	if (odd) {
#ifdef __LITTLE_ENDIAN
		result += (*buff << 8);
#else
		result = *buff;
#endif
		len--;
		buff++;
	}
	if (len >= 2) {
		if (2 & (unsigned long) buff) {
			result += *(unsigned short *) buff;
			len -= 2;
			buff += 2;
		}
		if (len >= 4) {
			const unsigned char *end = buff + ((unsigned)len & ~3);
			unsigned int carry = 0;
			do {
				unsigned int w = *(unsigned int *) buff;
				buff += 4;
				result += carry;
				result += w;
				carry = (w > result);
			} while (buff < end);
			result += carry;
			result = (result & 0xffff) + (result >> 16);
		}
		if (len & 2) {
			result += *(unsigned short *) buff;
			buff += 2;
		}
	}
	if (len & 1)
#ifdef __LITTLE_ENDIAN
		result += *buff;
#else
		result += (*buff << 8);
#endif
	result = from32to16(result);
	if (odd)
		result = ((result >> 8) & 0xff) | ((result & 0xff) << 8);
out:
	return result;
}
// This is adapted slightly to not use kernel types
static uint16_t ip_compute_csum(const void *buff, int len)
{
	return (uint16_t)~do_csum((const unsigned char *)buff, len);
}
// End copied and pasted from linux/lib/checksum.c

template <class Verilated> auto testIpChecksum(std::vector<std::vector<uint8_t>> inData, bool record_vcd=false)
{
    typedef decltype(Verilated::axis_i_tdata) dataInT;

	VerilatedModel<Verilated> uut("udp.vcd", record_vcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	AXISSource<dataInT> inAxis(&clk, &uut.uut->sresetn, AxisSignals<dataInT>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tlast = &uut.uut->axis_i_tlast, .tdata = &uut.uut->axis_i_tdata}, inData);

	AXISSink<vluint16_t> outAxis(&clk, &uut.uut->sresetn, AxisSignals<vluint16_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tdata = &uut.uut->axis_o_csum});

	ResetGen resetGen(clk,uut.uut->sresetn, false);

	uut.addPeripheral(&inAxis);
	uut.addPeripheral(&outAxis);
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

template <class T> std::vector<std::vector<uint8_t>> convert_to_byte_vector_vector(std::vector<std::vector<T>> in)
{
    // Hack in a quick conver
    std::vector<std::vector<uint8_t>> ret;
    for(const auto &vec : in)
    {
        ret.push_back({});
        for(auto word: vec)
        {
            for(size_t i=0; i<sizeof(word); i++)
            {
                ret.back().push_back(word&0xFF);
                word >>= 8;
            }
        }
    }
    return ret;
}

template <class Verilated> void testChecksum(std::vector<std::vector<vluint16_t>> in)
{
	// UDP Checksum is same algorithm as IP checksum
	std::vector<std::vector<vluint16_t>> outData;
	for(size_t i=0; i < in.size(); i++)
	{
		outData.push_back({ip_compute_csum((unsigned char *)in[i].data(),in[i].size()*sizeof(in[i][0]))});
	}

	auto result = testIpChecksum<Verilated>(convert_to_byte_vector_vector(in));
	REQUIRE( result == convert_to_byte_vector_vector(outData));
}

TEMPLATE_TEST_CASE("ip_checksum: Test correct values", "[ip_checksum]", IP_CHECKSUM_VERILATED_CLASSES)
{
    SECTION("All zeros")
    {
        testChecksum<TestType>({{0x0,0x0,0x0,0x0}});
    }

    SECTION("Incrementing")
    {
        testChecksum<TestType>({{0x0,0x1,0x2,0x3},{0x0,0x1,0x2,0x3}});
    }

    SECTION("Known result")
    {
        testChecksum<TestType>({{0x00FE,0xC523,0xFDA1,0xD68A,0xAF02}}); // Should give 0xB6AE (https://www.youtube.com/watch?v=EmUuFRMJbss)
    }

    SECTION("FFFFs and incrementing")
    {
        testChecksum<TestType>({{0xFFFF,0xFFFF,0xFFFF,0xFFFF},{0x0,0x1,0x2,0x3}});
    }

}