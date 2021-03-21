#include "Peripheral.hpp"

#include "VerilatedModel.hpp"

Peripheral::Peripheral(VerilatedModelInterface *model)
{
model->addPeripheral(this);
}

void Peripheral::latch(void)
{
    for(auto itm : inputs)
    {
        itm->latch();
    }
}

void Peripheral::addInput(InputLatchBase *i)
{
    if(std::find(inputs.begin(), inputs.end(), i) != inputs.end())
    {
        throw std::logic_error("Attempt to register an input that is already registered");
    }
    inputs.push_back(i);
};

void Peripheral::removeInput(InputLatchBase *i)
{
    auto old_end = inputs.end();
    auto new_end = std::remove(inputs.begin(), inputs.end(), i);

    // I.E. if nothing was removed
    if(old_end == new_end)
    {
        throw std::logic_error("Attempt to remove input that was not registered");
    }
};