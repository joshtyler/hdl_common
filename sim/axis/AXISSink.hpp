#ifndef AXIS_SINK_HPP
#define AXIS_SINK_HPP

// Receive an AXIS stream and save it to a std::vector

#include "../other/ClockGen.hpp"
#include "../verilator/Peripheral.hpp"
#include <vector>

template <class dataT, class ctrlT=dataT> class AXISSink : public Peripheral
{
public:
	AXISSink(ClockGen &clk, const ctrlT &sresetn,
		ctrlT &ready, const ctrlT & validIn, const ctrlT &lastIn,
		const dataT &dataIn)
		:clk(clk), sresetn(sresetn), ready(ready), valid(validIn), last(lastIn),
		 data(dataIn)
	{
		addInput(&valid);
		addInput(&last);
		addInput(&data);

		resetState();
	};
	// Data is returned as a vector of vectors
	// Each element in the base vector is a packet
	// Each element in the subvector is a word
	std::vector<std::vector<dataT>> getData(void){return vec;};

	//Return number of times tlast has been received
	unsigned int getTlastCount(void) const {return vec.size()-1;};

	void eval(void) override
	{
		if(clk.getEvent() == ClockGen::Event::RISING)
		{
			if (sresetn == 1)
			{
				//std::cout << "Got clk rising edge, ready:" << (int)ready << " valid:" << (int)valid << std::endl;
				if(ready && valid)
				{
					//std::cout << "Pushing" << std::endl;
					curData.push_back(data);
					if(last)
					{
						vec.push_back(curData);
						curData = {};
					}
				}
			} else {
				resetState();
			}
		}
	}

private:
	ClockGen &clk;
	const ctrlT &sresetn;
	ctrlT &ready;
	InputLatch <ctrlT> valid;
	InputLatch <ctrlT> last;
	InputLatch <dataT> data;

	std::vector<std::vector<dataT>> vec;

	std::vector<dataT> curData;

	void resetState(void)
	{
		// Reset vector
		vec = {};
		curData = {};

		//Always be ready
		ready = 1;
	}
};

#endif
