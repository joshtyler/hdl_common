//  Copyright (C) 2021 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef GMIISOURCE_HPP
#define GMIISOURCE_HPP

#include <vector>
#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include "../other/PacketSourceSink.hpp"

class GMIISource : public Peripheral
{
public:
    GMIISource(VerilatedModelInterface *model, gsl::not_null<ClockGen *> clk_, gsl::not_null<vluint8_t *>eth_rxd_, gsl::not_null<vluint8_t *>eth_rxdv_, gsl::not_null<vluint8_t *>eth_rxer_, gsl::not_null<PacketSource<vluint8_t> *> data_source_)
		:Peripheral(model), clk(clk_), eth_rxd(eth_rxd_), eth_rxdv(eth_rxdv_), eth_rxer(eth_rxer), data_source(data_source_)
	{
        eth_rxd = 0;
        eth_rxdv = 0;
        eth_rxer = 0;
	};

	void eval(void) override;

private:
	ClockGen *clk;
    OutputWrapper<vluint8_t> eth_rxd;
    OutputWrapper<vluint8_t> eth_rxdv;
    OutputWrapper<vluint8_t> eth_rxer;

    PacketSource<uint8_t> *data_source;

    std::vector<uint8_t> current_packet;
    typename std::vector<uint8_t>::const_iterator iter = current_packet.end();

    unsigned int ipg_counter{0};

    static constexpr std::array<uint8_t,8> preamble = {0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0x55, 0xD5};
};

#endif
