// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when the msg.sender of a transfer is not a receipt managed by the
/// manager.
error UnmanagedReceiptTransfer();

/// @title IReceiptManagerV2
/// @notice Manager of an `IReceiptV2` MUST authorize transfers between peers in
/// addition to being directly responsible for `managerX` calls.
interface IReceiptManagerV2 {
    /// Authorise a receipt transfer. `IReceiptManagerV2` contract MUST REVERT if
    /// the transfer is unauthorized. NOT reverting means the transfer is
    /// authorized.
    ///
    /// This is not view so if there are any possible side effects the manager
    /// must ensure the `msg.sender` is trusted.
    ///
    /// @param from The address the receipt is being transferred from.
    /// @param to The address the receipt is being transferred to.
    /// @param ids The receipt IDs.
    /// @param amounts The amounts of the receipt being transferred.
    function authorizeReceiptTransfer3(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        external;
}
