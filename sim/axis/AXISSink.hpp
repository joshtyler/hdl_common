#ifndef AXIS_SINK_HPP
#define AXIS_SINK_HPP

// Receive an AXIS stream and save it to a std::vector
// N.B. Currently this does not support any kind of reset

#include "ClockGen.hpp"
#include "Peripheral.hpp"
#include <vector>

template <class dataT> class AXISSink : public Peripheral
{
public:
	AXISSink(ClockGen &clk, const vluint8_t &sresetn,
		vluint8_t &ready, const vluint8_t & validIn, const vluint8_t &lastIn,
		const dataT &dataIn)
		:clk(clk), sresetn(sresetn), ready(ready), valid(validIn), last(lastIn),
		 data(dataIn)
	{
		addInput(&valid);
		addInput(&last);
		addInput(&data);

		//Push empty vector so that the first element has something to add to
		vec.push_back(std::vector<dataT>());

		//Always be ready
		ready = 1;
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
	std::vector<std::vector<dataT>> getData(void) {return vec;};

	//Return number of times tlast has been received
	unsigned int getTlastCount(void) const {return vec.size()-1;};

	void eval(void) override
	{
		#warning "Doesn't currently handle reset in the middle of sim"
		if((clk.getEvent() == ClockGen::Event::RISING) and (sresetn == 1))
		{
			//std::cout << "Got clk rising edge, ready:" << (int)ready << " valid:" << (int)valid << std::endl;
			if(ready && valid)
			{
				//std::cout << "Pushing" << std::endl;
				vec[vec.size()-1].push_back(data);
				if(last)
				{
					vec.push_back(std::vector<dataT>());
				}
			}
		}
	}

private:
	ClockGen &clk;
	const vluint8_t &sresetn;
	vluint8_t &ready;
	InputLatch <vluint8_t> valid;
	InputLatch <vluint8_t> last;
	InputLatch <dataT> data;

	std::vector<std::vector<dataT>> vec;
};

#endif
