//  Copyright (C) 2021 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef GMIISINK_HPP
#define GMIISINK_HPP

#include <vector>
#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include "../verilator/VerilatedModel.hpp"
#include "../other/PacketSourceSink.hpp"
#include <zlib.h>

class GMIISinkException : public std::runtime_error
{
    using std::runtime_error::runtime_error;
};

class GMIISink : public Peripheral
{
public:
    GMIISink(gsl::not_null<VerilatedModelInterface *> model, gsl::not_null<ClockGen *> clk_, gsl::not_null<vluint8_t *>eth_txd_, gsl::not_null<vluint8_t *>eth_txen_, gsl::not_null<vluint8_t *>eth_txer_, gsl::not_null<PacketSink<vluint8_t> *> data_sink_)
		:Peripheral(model), clk(clk_), eth_txd(this, eth_txd_), eth_txen(this, eth_txen_), eth_txer(this, eth_txer_), data_sink(data_sink_)
	{
        current_packet.reserve(1538); // Standard MTU
	};

	void eval(void) override;

private:
	ClockGen *clk;
    InputLatch<vluint8_t> eth_txd;
    InputLatch<vluint8_t> eth_txen;
    InputLatch<vluint8_t> eth_txer;

    PacketSink<uint8_t> *data_sink;

    std::vector<uint8_t> current_packet;

    unsigned int ipg_counter{0};
};

#endif
