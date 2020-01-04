#ifndef UART_HPP
#define UART_HPP

#include <iostream>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
#include "../verilator/Peripheral.hpp"

template <class dataT> class Uart : public Peripheral
{
	public:
		Uart(const dataT &rxIn, dataT &tx, const int bit_interval)
			:rx(rxIn), tx(tx), bit_interval(bit_interval), rx_state(State::IDLE), tx_state(State::IDLE)
		{
			addInput(&rx);

			// Open /dev/ptmx to create the master side of the pty
			fd = posix_openpt(O_RDWR);

			// Set the permissions of the slave side to match the master side
			int ret = grantpt(fd);
			if(ret != 0)
			{
				throw std::runtime_error("grantpt failed");
			}

			// Unlock the slave side
			ret = unlockpt(fd);
			if(ret != 0)
			{
				throw std::runtime_error("unlockpt failed");
			}

			// Set as non-blocking
			fcntl(fd, F_SETFL, FNDELAY);

			std::cout << "The slave side is named: " << ptsname(fd) << std::endl;
		}

		~Uart()
		{
			close(fd);
		}

		void eval(void) override
		{

			rx_eval();
			tx_eval();
		}

	private:
		InputLatch <dataT> rx;
		dataT &tx;
		const int bit_interval;
		int rx_timer, tx_timer, rx_bit, tx_bit;
		int fd;

		enum class State
		{
			IDLE,
			DATA,
		};

		State rx_state, tx_state;

		uint8_t rx_data, tx_data;

		void rx_eval(void)
		{
			switch(rx_state)
			{
				case State::IDLE:
					if((int) rx != 1)
						std::cout << (int) rx << std::endl;

					if(!rx)
					{
						rx_state = State::DATA;
						rx_bit = 9;
						rx_timer = bit_interval/2; // Sample half way through each bit
						rx_data = 0;
						std::cout << "Starting receive! (" << (int) rx << ")" << std::endl;
					}
					break;
				case State::DATA:
					if(rx_timer)
					{
						rx_timer--;
					} else {
						if(rx_bit == 9)
						{
							// Start bit
							assert(!rx /* Start bit not low */);
						} else if(rx_bit == 0) {
							// Stop bit
							assert(rx /* Stop bit not high*/);
							std::cout << "Got data bit: " << std::hex << (int) rx_data << std::dec << std::endl;
							if(write(fd,&rx_data,1) != 1)
							{
								throw std::runtime_error("Writing failed");
							}
							rx_state = State::IDLE;
						} else {
							// Data
							if(rx)
							{
								rx_data |= (1 << (rx_bit-1));
							}
						}
						rx_timer = bit_interval;
						rx_bit--;
					}
					break;
			}
		}

		void tx_eval(void)
		{
			switch(tx_state)
			{
				case State::IDLE:
					tx = 1;
					if(read(fd, &tx_data, 1) == 1)
					{
						tx_state = State::DATA;
						tx_bit = 9;
						tx_timer = bit_interval;
					} else if(!(errno == EAGAIN || errno == EWOULDBLOCK)) { // If we failed for any reason OTHER than data not available
						std::cerr << "Something went wrong with read(): " << strerror(errno) << std::endl;
						throw std::runtime_error("Reading failed");
					}
					break;
				case State::DATA:
					if(tx_timer)
					{
						tx_timer--;
					} else {
						//std::cout << "Tx: " << (int)tx << "Tx bit: " << tx_bit << std::endl;
						if(tx_bit == 9)
						{
							// Start bit
							tx = 0;
						} else if(tx_bit == 0) {
							// Stop bit
							tx = 1;
						} else {
							// Data
							tx = static_cast<bool>((1 << (tx_bit-1)) & tx_data);
							//std::cout << "Setting to " << (int) tx << "(data : " << (int) tx_data << ")" << std::endl;
						}
						tx_timer = bit_interval;
						if(tx_bit)
						{
							tx_bit--;
						} else {
							std::cout << "TX Done!" << std::endl;
							tx_state = State::IDLE;
						}
					}
					break;
			}
		}
};

#endif
