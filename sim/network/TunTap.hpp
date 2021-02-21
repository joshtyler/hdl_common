#ifndef TUNTAP_HPP
#define TUNTAP_HPP

#include <stdexcept>

#include "../other/PacketSourceSink.hpp"

class TunTapException : public std::runtime_error
{
    using std::runtime_error::runtime_error;
};

class TunTapInterface : public PacketSource<uint8_t>, public PacketSink<uint8_t>
{
public:
    virtual ~TunTapInterface()
    {
        close(fd);
    }

    int getMtu() const {return mtu;};
    const std::string& getName() const {return name;};

protected:
    enum class Type
    {
        TUN,
        TAP
    };

    // Make either a TUN or a TAP interface
    // If a name is provided, then try and open up the device with that name, otherwise let the kernel choose
    // N.B. This works both for creating a new interface, as well as connecting to an existing interface (e.g. make with iproute2)
    // Make this protected so that only the inheriting TUN/TAP classes can be used in code
    TunTapInterface(Type t, const char *dev_name=nullptr);

    void send(std::span<uint8_t> data) override;
    std::optional<std::vector<uint8_t>> receive() override;

private:
    int fd;
    int mtu;
    std::string name;
};

// IP level interface
class Tun : public TunTapInterface
{
public:
    Tun(const char *dev_name=nullptr) :TunTapInterface(Type::TUN, dev_name) {};
};

// Ethernet level interface
class Tap : public TunTapInterface
{
public:
    Tap(const char *dev_name=nullptr) :TunTapInterface(Type::TAP, dev_name) {};
};

#endif
