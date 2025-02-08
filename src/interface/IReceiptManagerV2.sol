// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IReceiptManagerV2
/// @notice Manager of an `IReceiptV2` MUST authorize transfers between peers in
/// addition to being directly responsible for `managerX` calls.
interface IReceiptManagerV2 {
    /// Authorise a receipt transfer. `IReceiptManagerV2` contract MUST REVERT if
    /// the transfer is unauthorized. NOT reverting means the transfer is
    /// authorized.
    /// @param from The address the receipt is being transferred from.
    /// @param to The address the receipt is being transferred to.
    /// @param ids The receipt IDs.
    /// @param amounts The amounts of the receipt being transferred.
    function authorizeReceiptTransfer3(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        external
        view;
}
