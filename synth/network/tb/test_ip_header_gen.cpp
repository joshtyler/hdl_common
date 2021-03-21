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
#include "../../../sim/other/PacketSourceSink.hpp"

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

auto testip(uint64_t src_ip, uint64_t dest_ip, uint8_t protocol, std::vector<std::vector<vluint8_t>> len, std::string vcdName="foo.vcd", bool recordVcd=false)
{
	VerilatedModel<Vip_header_gen> uut(vcdName, recordVcd);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	uut.uut->axis_i_src_ip = src_ip;
	uut.uut->axis_i_dst_ip = dest_ip;
	uut.uut->axis_i_protocol = protocol;

    SimplePacketSource<uint8_t> lenSource(len);
	AXISSource<vluint16_t, vluint8_t> lenAxis(&uut, &clk, &uut.uut->sresetn, AxisSignals<vluint16_t, vluint8_t>{.tready = &uut.uut->axis_i_tready, .tvalid = &uut.uut->axis_i_tvalid, .tdata = &uut.uut->axis_i_length_bytes}, &lenSource);

    SimplePacketSink<uint8_t> outAxisSink;
	AXISSink<vluint32_t, vluint8_t> outAxis(&uut, &clk, &uut.uut->sresetn, AxisSignals<vluint32_t, vluint8_t>{.tready = &uut.uut->axis_o_tready, .tvalid = &uut.uut->axis_o_tvalid, .tlast = &uut.uut->axis_o_tlast, .tkeep = &uut.uut->axis_o_tkeep, .tdata = &uut.uut->axis_o_tdata}, &outAxisSink);


	ResetGen resetGen(&uut, clk,uut.uut->sresetn, false);

	ClockBind clkDriver(clk,uut.uut->clk);
	uut.addClock(&clkDriver);

	while(true)
	{
        if(uut.eval() == false || uut.getTime() == 10000 || len.size() == outAxisSink.getNumPackets())
        {
            break;
        }
	}
    return outAxisSink.getData();
}

TEST_CASE("Test with random UDP packet", "[ip_header_gen]")
{
	// Based off a packet captured off the wire
	// Modified to match identification, TTL, etc.
	std::vector<vluint8_t> outData =
		{0x45,0x00, 0x00, 0x21,
         0x00, 0x00, 0x40, 0x00,
         0xFF, 0x11, 0x00, 0x00,
		 0xC0, 0xA8, 0x00, 0x1F,
		 0xC0, 0xA8, 0x00, 0x23}
	;

	auto csum = ip_compute_csum(outData.data(), outData.size());
	std::cout << "Checksum: 0x" << std::hex << csum << std::dec << std::endl;
	outData[10] = csum & 0xFF;
	outData[11] = (csum >> 8) & 0xFF;

	uint64_t src_ip = 0xC0A8001F; //192.168.0.31
	uint64_t dest_ip = 0xC0A80023; //192.168.0.35
	uint8_t protocol = 0x11; //UDP
	auto result = testip(src_ip, dest_ip, protocol, {{13,0}}, "ip.vcd",true);
	REQUIRE(outData == result.at(0));
}
