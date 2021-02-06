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
#include "../verilator/Peripheral.hpp"
#include <gsl/pointers>
#include <vector>

struct AXISSinkConfig
{
    bool packed = false;
};

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0> class AXISSink : public Peripheral
{
public:
	AXISSink(gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_, AXISSinkConfig _config=AXISSinkConfig{})
		:clk(clk_), sresetn(sresetn_), tready(signals_.tready), tvalid(signals_.tvalid), tlast(signals_.tlast), tkeep(signals_.tkeep), tdata(signals_.tdata), packed(_config.packed)
	{
        addInput(&sresetn);
		addInput(&tvalid);
		addInput(&tlast);
		addInput(&tdata);
		addInput(&tkeep);
		for(size_t i=0; i<tusers.size(); i++)
        {
		    tusers[i] = InputLatch<userT>(signals_.tusers.at(i));
            addInput(&tusers[i]);

        }
		resetState();
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
    auto getData(void){return datas;};
    auto getUsers(void){return users;};

	//Return number of times tlast has been received
	unsigned int getTlastCount(void) const {return datas.size();};

	void eval(void) override
	{
		if(clk->getEvent() == ClockGen::Event::RISING)
		{
			if (sresetn == 1)
			{
				//std::cout << "Got clk rising edge, ready:" << (int)ready << " valid:" << (int)valid << std::endl;
				if(tready && tvalid)
				{
					if(!tdata.is_null()) {
                        cur_data_natural_width.push_back(tdata);
                        const keepT max_tkeep = static_cast<keepT>((1 << sizeof(dataT))-1);

                        keepT keep = tkeep.is_null()? max_tkeep : tkeep;
                        dataT data = tdata;

                        // Check tkeep
                        if(packed) {
                            if (tlast.is_null() || tlast) {
                                if (keep <= max_tkeep)
                                    throw std::runtime_error("keep indicating too many bytes on last beat!");
                                if ((keep & (keep + 1)) == 0)
                                    throw std::runtime_error("keep unpacked on tlast"); // Enforce that all bits are unset after the first unset bit. I.e tkeep is one less than a power of 2
                            } else {
                                if (keep == max_tkeep)
                                    throw std::runtime_error("Checking for packed stream, but tkeep not all ones with tlast false");
                            }
                        }

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

                    std::array<userT, n_users> user_values;
                    std::copy(tusers.begin(), tusers.end(), user_values.begin());
                    curUsers.push_back(user_values);

					if(tlast.is_null() || tlast)
					{
                        datas_natural_width.push_back(cur_data_natural_width);
                        datas.push_back(cur_data);
                        users.push_back(curUsers);
                        resetPacket();
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
    // Do not be tempted to make this a vector
    // The location of each element needs to be fixed in memory since we register it as an input
    std::array<InputLatch<userT>, n_users> tusers;

	std::vector<std::vector<dataT>> datas_natural_width;
    std::vector<std::vector<uint8_t>> datas;
    // Outer dimension is each packet
    // Inner dimension is each beat
    // Inner inner dimension is each user
    std::vector<std::vector<std::array<userT, n_users>>> users;

	std::vector<dataT> cur_data_natural_width;
    std::vector<uint8_t> cur_data;
    std::vector<std::array<userT, n_users>> curUsers;

    bool packed;

	void resetState(void)
	{
		// Reset vectors
		datas = {};
        users = {};
        resetPacket();

		//Always be ready
		tready = 1;
	}

	void resetPacket(void)
    {
        cur_data = {};
        cur_data_natural_width = {};
        curUsers = {};
    }
};

#endif
