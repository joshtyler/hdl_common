#ifndef UART_HPP
#define UART_HPP

#include <iostream>
#include "../verilator/Peripheral.hpp"

template <class dataT> class Uart : public Peripheral
{
	public:
		Uart(const dataT &rx, dataT &tx)
			:rx(rx), tx(tx), bit_interval(10000), rx_state(State::IDLE) {};

		void eval(void) override
		{

			rx_eval();
			tx = 1;
		}

	private:
		InputLatch <dataT> rx;
		dataT &tx;
		const int bit_interval;
		int rx_timer, tx_timer, rx_bit, tx_bit;

		enum class State
		{
			IDLE,
			DATA,
		};

		State rx_state, tx_state;

		uint8_t rx_data;

		void rx_eval(void)
		{
			switch(rx_state)
			{
				case State::IDLE:
					if(!rx)
					{
						rx_state = State::DATA;
						rx_bit = 8;
						rx_timer = bit_interval/2; // Sample half way through each bit
						rx_data = 0;
					}
					break;
				case State::DATA:
					if(rx_timer)
					{
						rx_timer--;
					} else {
						if(rx_bit == 8)
						{
							// Start bit
							assert(!rx);
						} else if(rx_bit == 0) {
							// Stop bit
							assert(rx);
							std::cout << "Got data bit: " << std::hex << (int) rx_data << std::dec << std::endl;
							rx_state = State::IDLE;
						} else {
							// Data
							if(rx)
							{
								rx_data |= (1 << (rx_bit-1));
							}
						}
						rx_timer = bit_interval;
					}
					break;
			}
		}
};

#endif
