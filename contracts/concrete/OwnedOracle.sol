// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IPriceOracleV1} from "../oracle/price/IPriceOracleV1.sol";

/// @title OwnedOracle
/// A simple oracle that allows the owner to set the price.
/// This is useful for testing and development purposes.
/// Strongly discouraged for production use.
contract OwnedOracle is Ownable, IPriceOracleV1 {
    /// @inheritdoc IPriceOracleV1
    uint256 public price;

    /// Emitted when the price is set.
    /// @param oldPrice The old price.
    /// @param newPrice The new price.
    event Price(uint256 oldPrice, uint256 newPrice);

    /// Owner can set a new price to anything they want.
    /// @param newPrice The new price to set.
    function setPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = price;
        price = newPrice;
        emit Price(oldPrice, newPrice);
    }
}