// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../oracle/price/IPriceOracle.sol";

/// @title MockPriceOracle
/// @notice Mock for a price oracle.
/// TODO Autogenerate mocks e.g. https://github.com/defi-wonderland/smock
contract MockPriceOracle is IPriceOracle {
    /// @dev mock can set price.
    uint256 private _price;

    /// Setter for _price.
    /// @param price_ The new value for _price.
    function setPrice(uint256 price_) external {
        _price = price_;
    }

    /// @inheritdoc IPriceOracle
    function price() external view override returns (uint256) {
        return _price;
    }
}
