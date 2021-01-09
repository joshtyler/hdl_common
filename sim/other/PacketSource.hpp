#ifndef PACKETSOURCE_HPP
#define PACKETSOURCE_HPP

#include <vector>
#include <optional>

template <class DataT> class PacketSource
{
public:
    virtual ~PacketSource()=default;

    // Try and get a packet from a packet source
    virtual std::optional<std::vector<DataT>> get_packet() = 0;
};

#endif
