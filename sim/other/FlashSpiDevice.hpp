#ifndef FLASH_SPI_DEVICE_HPP
#define FLASH_SPI_DEVICE_HPP

#include "SpiDeviceInterface.hpp"

// Based on W25Q128JV

class FlashSpiDevice : public SpiDeviceInterface<uint8_t>
{
	public:
		FlashSpiDevice()
			:rx_state(RxState::INSTRUCTION)
		{

		}

		virtual uint8_t ss_fall() override
		{
			std::cout << "SS fell" << std::endl;
			rx_state = RxState::INSTRUCTION;
			return 0;
		}

		virtual uint8_t transfer(uint8_t rx) override
		{
			std::cout << "Got data!" << std::endl;
			uint8_t ret;
			switch(rx_state)
			{
				case RxState::INSTRUCTION:
					instruction = rx;
					ret = 0;
					rx_state = RxState::ADDRESS_1;
					break;
				case RxState::ADDRESS_1:
					address = rx << 16;
					ret = 0;
					rx_state = RxState::ADDRESS_2;
					break;
				case RxState::ADDRESS_2:
					address |= rx << 8;
					ret = 0;
					rx_state = RxState::ADDRESS_3;
					break;
				case RxState::ADDRESS_3:
					address |= rx;
					rx_state = RxState::INSTRUCTION;
					switch(instruction)
					{
						case 0x90: // Manufacturer ID
							std::cout << "Returning manufacturer ID" << std::endl;
							ret = 0xEF;
							#warning "Really we should return device ID here after manufaturer ID"
							break;
						default:
							assert(false); // Unknown ID
							break;
					}
					break;
			}

			return ret;
		}

		virtual void ss_rise() override
		{
			std::cout << "SS rose" << std::endl;
		}

	private:
		enum class RxState
		{
			INSTRUCTION,
			ADDRESS_1,
			ADDRESS_2,
			ADDRESS_3
		};
		RxState rx_state;

		uint8_t instruction;
		uint32_t address; // Only use 24 bits
};

#endif
