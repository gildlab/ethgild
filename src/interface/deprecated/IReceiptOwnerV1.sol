// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title IReceiptOwnerV1
/// @notice Owner of an `IReceiptV1` MUST authorize transfers between peers in
/// addition to being directly responsible for `ownerX` calls.
interface IReceiptOwnerV1 {
    /// Authorise a receipt transfer. `IReceiptOwnerV1` contract MUST REVERT if
    /// the transfer is unauthorized. NOT reverting means the transfer is
    /// authorized.
    /// @param from The address the receipt is being transferred from.
    /// @param to The address the receipt is being transferred to.
    function authorizeReceiptTransfer(address from, address to) external view;
}
