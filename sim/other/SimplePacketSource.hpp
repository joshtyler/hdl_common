#ifndef SIMPLEPACKETSOURCE_HPP
#define SIMPLEPACKETSOURCE_HPP

#include <vector>
#include <optional>

#include "PacketSource.hpp"

template <class T> class SimplePacketSource : public PacketSource<T>
{
public:
    SimplePacketSource(std::vector<std::vector<uint8_t>> data_) : data(data_) {};

    // Try and get a packet from a packet source
    std::optional<std::vector<T>> get_packet() override {return data.pop_front();};

private:
    std::vector<std::vector<T>> data;
};

#endif
