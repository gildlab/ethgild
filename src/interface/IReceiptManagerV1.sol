// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

/// @title IReceiptManagerV1
/// @notice Manager of an `IReceiptV2` MUST authorize transfers between peers in
/// addition to being directly responsible for `managerX` calls.
interface IReceiptManagerV1 {
    /// Authorise a receipt transfer. `IReceiptManagerV1` contract MUST REVERT if
    /// the transfer is unauthorized. NOT reverting means the transfer is
    /// authorized.
    /// @param from The address the receipt is being transferred from.
    /// @param to The address the receipt is being transferred to.
    function authorizeReceiptTransfer2(address from, address to) external view;
}
