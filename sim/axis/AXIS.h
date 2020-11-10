#ifndef AXIS_H
#define AXIS_H

#include <verilated.h>
#include <vector>

// Struct of Axis signals so that we can have sane constructors
template <class dataT, class keepT=dataT, class userT=dataT> struct AxisSignals
{
    gsl::not_null<vluint8_t *> tready;
    gsl::not_null<vluint8_t *> tvalid;
    vluint8_t *tlast = nullptr;
    keepT *tkeep = nullptr;
    dataT *tdata = nullptr;
    // Support having multiple user signals as multiple sideband signals are possible
    std::vector<userT *> tusers;
};

#endif //AXIS_H
