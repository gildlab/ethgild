// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../oracle/price/IPriceOracle.sol";

contract TestPriceOracle is IPriceOracle {
    uint private _price;

    function setPrice(uint price_) public {
        _price = price_;
    }

    function price() external view override returns (uint) {
        return _price;
    }
}
