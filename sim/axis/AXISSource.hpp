//  Copyright (C) 2019 Joshua Tyler
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.
//  See the file LICENSE_LGPL included with this distribution for more
//  information.

#ifndef AXIS_SOURCE_HPP
#define AXIS_SOURCE_HPP

// Output an AXI Stream from a vector of vectors
// N.B. Currently this does not support any kind of reset
#include <vector>
#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include "../other/PacketSourceSink.hpp"

struct AXISSourceConfig
{
    bool packed = true;
};

struct AXISSourceException : std::runtime_error
{
    using std::runtime_error::runtime_error;
};

// Helper class to handle the sideband tuser signal
template <class userT> class AxisSourceUserHandler
{
public:
    AxisSourceUserHandler(userT *tuser_, gsl::not_null<PacketSource<userT> *> source_)
    :tuser(tuser_), source(source_)
    {
    }

    // Call this to output the next value i.e. when tready and tvalid
    void output(bool last)
    {
        if(last && iter != current_packet.end()) throw("AxisSource output last, but tuser packet wasn't empty");
        if(iter == current_packet.end())
        {
            auto maybe_new_packet = source->receive();
            if(!maybe_new_packet) throw AXISSourceException("tuser packet source couldn't provide packet when required");
            current_packet = *maybe_new_packet;
            iter = current_packet.begin();
        }
        tuser = *(iter++);
    }

    std::vector<userT> current_packet;
    typename std::vector<userT>::const_iterator iter = current_packet.end();

private:
    OutputWrapper<userT> tuser;
    PacketSource<userT> *source;

};

// Due to the way that we are structured, we mandate that a data source is provided
// This is required because the data and the data only is responsible for setting packet length, total number of packets etc.
// If there truly is no data source, a dummy one needs to be provided externally (if tdata is null this is no problem, the data will be silently discarded)
// As a side effect, tusers must always be able to produce data when data is valid

template <class dataT, class keepT=dataT, class userT=dataT, unsigned int n_users=0>class AXISSource : public Peripheral
{
public:
	AXISSource(VerilatedModelInterface *model, gsl::not_null<ClockGen *> clk_, const gsl::not_null<vluint8_t *> sresetn_, const AxisSignals<dataT, keepT, userT, n_users> &signals_, gsl::not_null<PacketSource<uint8_t> *> data_source_, std::array<PacketSource<userT>*, n_users> users_source_=std::array<PacketSource<userT>*, n_users>{}, AXISSourceConfig _config=AXISSourceConfig{})
		:Peripheral(model), clk(clk_), sresetn(this, sresetn_, 1), tready(this, signals_.tready, 1), tvalid(signals_.tvalid), tlast(signals_.tlast), tkeep(signals_.tkeep), tdata(signals_.tdata), data_source(data_source_), output_packed(_config.packed)
	{
	    for(size_t i=0; i < n_users; i++)
        {
            users.at(i) = AxisSourceUserHandler<userT>(signals_.tusers.at(i), users_source_.at(i));
        }
		tvalid = 0;
	};
	void eval(void) override
	{
		if((clk->getEvent() == ClockGen::Event::RISING))
		{
			if(sresetn == 0)
			{
                tvalid = 0;
            } else {
				if((tready && tvalid) || (!tvalid))
				{
                    setupNextData();
                }
			}
		}
	}

private:
	ClockGen *clk;
    InputLatch<vluint8_t> sresetn;
	InputLatch<vluint8_t> tready;
    OutputWrapper<vluint8_t> tvalid;
    OutputWrapper<vluint8_t> tlast;
    OutputWrapper<keepT> tkeep;
    OutputWrapper<dataT> tdata;

    std::array<AxisSourceUserHandler<userT>, n_users> users;

    bool output_packed;

    PacketSource<uint8_t> *data_source;
    std::vector<uint8_t> current_packet;
    typename std::vector<uint8_t>::const_iterator iter = current_packet.end();

	void setupNextData(void)
    {
	    // Setup no data
        tvalid = 0;

        // If we have run out of data, try and get more
        if(iter == current_packet.end())
        {
            auto maybe_new_packet = data_source->receive();
            if(maybe_new_packet) {
                current_packet = *maybe_new_packet;
                iter = current_packet.begin();
            }
        }

        // If we have data to give, present that
	    if(iter != current_packet.end())
        {

            int max_num_bytes = std::min<int>(current_packet.end()-iter, sizeof(dataT));

            tvalid = 1;
            tdata = 0;
            tkeep = 0;

            for(int i=0; i<max_num_bytes; i++)
            {

                if(output_packed || (rand() > (RAND_MAX / 2)))
                {
                    tdata = tdata | (*(iter++) << i * 8);
                    tkeep = tkeep | (1 << i);
                }
            }

            tlast = (iter == current_packet.end());
            for(auto &user : users)
            {
                if(!output_packed) throw(AXISSourceException("tdata requested to be sent unpacked, whilst tusers also being used"));
                user.output(tlast);
            }
        }
    }
};

#endif
