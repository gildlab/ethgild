// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../oracle/price/IPriceOracle.sol";

contract TestPriceOracle is IPriceOracle {
    uint256 private _price;

    function setPrice(uint256 price_) public {
        _price = price_;
    }

    function price() external view override returns (uint256) {
        return _price;
    }
}
