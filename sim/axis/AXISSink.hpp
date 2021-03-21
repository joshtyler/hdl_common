//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef AXIS_SINK_HPP
#define AXIS_SINK_HPP

// Receive an AXIS stream and save it to a std::vector

#include "AXIS.h"
#include "../other/ClockGen.hpp"
#include "../other/PacketSourceSink.hpp"
#include "../verilator/Peripheral.hpp"
#include "../verilator/VerilatedModel.hpp"
#include <gsl/pointers>
#include <vector>

struct AXISSinkConfig
{
    bool packed = false;
};

template <class dataT, class keepT> keepT static constexpr maxTkeep()
{
    return static_cast<keepT>((1 << sizeof(dataT))-1);
}

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0> class AXISSink : public Peripheral
{
public:
	AXISSink(gsl::not_null<VerilatedModelInterface *> model, gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_, PacketSink<uint8_t> *data_sink_, std::array<PacketSink<userT>*, n_users> users_sink_=std::array<PacketSink<userT>*, n_users>{}, AXISSinkConfig _config=AXISSinkConfig{})
		:Peripheral(model),
		 clk(clk_),
		 sresetn(this, sresetn_, true),
		 tready(signals_.tready),
		 tvalid(this, signals_.tvalid, true),
		 tlast(this, signals_.tlast, true),
		 tkeep(this, signals_.tkeep, maxTkeep<dataT, keepT>()),
		 tdata(this, signals_.tdata),
		 data_sink(data_sink_),
		 users_sink(users_sink_),
		 packed(_config.packed)
	{
		for(const auto&tuser_sig : signals_.tusers)
        {
		    tusers.push_back(InputLatch<userT>(this, tuser_sig));
        }
		resetState();
	};

	void eval(void) override
	{
		if(clk->getEvent() == ClockGen::Event::RISING)
		{
			if (sresetn == 1)
			{
				if(tready && tvalid)
				{
					if(!tdata.is_null())
					{

                        // Check tkeep
                        if(packed) {
                            if (tkeep > maxTkeep<dataT, keepT>())
                            {
                                throw std::runtime_error("tkeep indicating more bytes are valid than bytes that exist, on last beat! This should be impossible without mis-sized vectors!");
                            }

                            // Enforce that all bits are unset after the first unset bit. I.e tkeep is one less than a power of 2
                            bool seen_unset_bit = false;
                            for(int i=0; i<sizeof(dataT); i++)
                            {
                                bool current_bit_set = tkeep & (1 << i);
                                if(seen_unset_bit && current_bit_set)
                                {
                                    throw("tkeep is unpacked on tlast");
                                }
                                seen_unset_bit |= (!current_bit_set);
                            }

                            if (!tlast)
                            {
                                if (tkeep != maxTkeep<dataT, keepT>())
                                {
                                    throw std::runtime_error("tkeep not all ones with tlast false");
                                }
                            }
                        }

                        // Store the data byte by byte
                        dataT data = tdata;
                        keepT keep = tkeep;
                        for(size_t i=0; i<sizeof(dataT); i++)
                        {
                            if(keep & 1)
                            {
                                cur_data.push_back(data & 0xFF);
                            }
                            keep >>= 1;
                            data >>= 8;
                        }
                    }

                    for(size_t i=0; i < curUsers.size(); i++)
                    {
                        curUsers.at(i).push_back(tusers.at(i));
                    }

                    // Dispatch the completed packets on tlast
					if(tlast)
					{
					    if(data_sink)
					    {
                            data_sink->send(cur_data);
                        }

                        cur_data = {};
					    for(size_t i=0; i < curUsers.size(); i++)
                        {
					        if(users_sink.at(i))
                            {
                                users_sink.at(i)->send(curUsers[i]);
                            }
                            curUsers.at(i) = {};
                        }
					}
				}
			} else {
				resetState();
			}
		}
	}

private:
    ClockGen *clk;
    InputLatch<vluint8_t> sresetn;
    OutputWrapper<vluint8_t> tready;
	InputLatch <vluint8_t> tvalid;
	InputLatch <vluint8_t> tlast;
    InputLatch <keepT> tkeep;
	InputLatch <dataT> tdata;

    std::vector<InputLatch<userT>> tusers;

    std::vector<uint8_t> cur_data;
    std::array<std::vector<userT>, n_users> curUsers;

    PacketSink<uint8_t> *data_sink;
    std::array<PacketSink<userT>*, n_users> users_sink;

    bool packed;

	void resetState(void)
	{
        cur_data = {};
        curUsers = {};
		tready = 1;
	}

};

#endif
