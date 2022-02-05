// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../price/IPriceOracle.sol";

contract TestPriceOracle is IPriceOracle {
    uint8 private _decimals;
    uint private _price;

    function setDecimals(uint8 decimals_) public {
        _decimals = decimals_;
    }

    function setPrice(uint price_) public {
        _price = price_;
    }

    function price() external view override returns (uint8, uint) {
        return (_decimals, _price);
    }
}
