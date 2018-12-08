#include <catch2/catch.hpp>
#include <iostream>
#include <verilated.h>
#include "Vudp_checksum.h"

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
uint16_t ip_compute_csum(const void *buff, int len)
{
	return (uint16_t)~do_csum((const unsigned char *)buff, len);
}
// End copied and pasted from linux/lib/checksum.c

auto testUdpChecksum(std::vector<std::vector<vluint16_t>> inData)
{
	VerilatedModel<Vudp_checksum> uut("udp.vcd", false);

	ClockGen clk(uut.getTime(), 1e-9, 100e6);

	AXISSource<vluint16_t, vluint8_t> inAxis(clk, uut.uut->sresetn, uut.uut->axis_i_tready,
		uut.uut->axis_i_tvalid, uut.uut->axis_i_tlast, uut.uut->axis_i_tdata,
		inData);

	AXISSink<vluint16_t, vluint8_t> outAxis(clk, uut.uut->sresetn, uut.uut->axis_o_tready,
		uut.uut->axis_o_tvalid, uut.uut->axis_o_tlast, uut.uut->axis_o_tdata);

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
			break;
		}
		// Break after a timeout
		if(uut.getTime() == 10000)
		{
			break;
		}
	}
	return outAxis.getData();
}

void testChecksum(std::vector<std::vector<vluint16_t>> in)
{
	// UDP Checksum is same algorithm as IP checksum
	std::vector<std::vector<vluint16_t>> outData;
	for(size_t i=0; i < in.size(); i++)
	{
		outData.push_back({ip_compute_csum((unsigned char *)in[i].data(),in[i].size()*sizeof(in[i][0]))});
	}
	auto result = testUdpChecksum(in);
	REQUIRE( result == outData);
}

TEST_CASE("Test checksum calculator gets correct value", "[test_udp_checksum]")
{
	//std::vector<std::vector<vluint16_t>> testData = {{0x0,0x1,0x2,0x3}};
	std::vector<std::vector<vluint16_t>> testData = {{0x0,0x0,0x0,0x0}};
	//std::vector<std::vector<vluint16_t>> testData = {{0x00FE,0xC523,0xFDA1,0xD68A,0xAF02}};
	testChecksum({{0x0,0x0,0x0,0x0}});
	testChecksum({{0x0,0x1,0x2,0x3},{0x0,0x1,0x2,0x3}});
	testChecksum({{0x00FE,0xC523,0xFDA1,0xD68A,0xAF02}}); // Should give 0xB6AE (https://www.youtube.com/watch?v=EmUuFRMJbss)
	testChecksum({{0xFFFF,0xFFFF,0xFFFF,0xFFFF},{0x0,0x1,0x2,0x3}});

}
