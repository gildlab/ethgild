// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {IPriceOracleV1} from "../../interface/IPriceOracleV1.sol";

/// @title OwnableOracle
/// A simple oracle that allows the owner to set the price.
/// This is useful for testing and development purposes.
/// Strongly discouraged for production use.
contract OwnableOracle is Ownable, IPriceOracleV1 {
    /// @inheritdoc IPriceOracleV1
    uint256 public price;

    /// Emitted when the price is set.
    /// @param oldPrice The old price.
    /// @param newPrice The new price.
    event Price(uint256 oldPrice, uint256 newPrice);

    constructor() {
        _transferOwnership(msg.sender);
    }

    /// Owner can set a new price to anything they want.
    /// @param newPrice The new price to set.
    function setPrice(uint256 newPrice) external onlyOwner {
        uint256 oldPrice = price;
        price = newPrice;
        emit Price(oldPrice, newPrice);
    }
}
