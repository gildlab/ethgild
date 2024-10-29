// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {IReceiptV1} from "src/interface/IReceiptV1.sol";
import {IReceiptOwnerV1} from "src/interface/IReceiptOwnerV1.sol";

/// Thrown when a transfer is not authorized.
/// @param from The transfer attempted from this address.
/// @param to The transfer attemped to this address.
error UnauthorizedTransfer(address from, address to);

/// @title TestReceiptOwner
/// @notice TEST contract that can be the owner of an `IReceiptV1` and forward
/// function calls to the owner restricted functions on the receipt. Completely
/// insecure, intended for use only by the test harness to drive ownership tests.
contract TestReceiptOwner is IReceiptOwnerV1 {
    /// The address that is authorized to send transfers.
    address internal sFrom;
    /// The address that is authorized to receive transfers.
    address internal sTo;

    /// Anon can set the from address.
    /// @param from The new `from` address.
    function setFrom(address from) external {
        sFrom = from;
    }

    /// Anon can set the to address.
    /// @param to The new `to` address.
    function setTo(address to) external {
        sTo = to;
    }

    /// Only transfers between `from` and `to` are authorized.
    /// @inheritdoc IReceiptOwnerV1
    function authorizeReceiptTransfer(address from, address to) external view {
        if (sFrom != from) {
            revert UnauthorizedTransfer(from, to);
        }
        if (sTo != to) {
            revert UnauthorizedTransfer(from, to);
        }
    }

    /// Exposes `IReceiptV1.ownerMint` to anon.
    /// @param receipt The `IReceiptV1` contract to call.
    /// @param account As per `IReceiptV1.ownerMint`.
    /// @param id As per `IReceiptV1.ownerMint`.
    /// @param amount As per `IReceiptV1.ownerMint`.
    /// @param data As per `IReceiptV1.ownerMint`.
    function ownerMint(IReceiptV1 receipt, address account, uint256 id, uint256 amount, bytes memory data) external {
        receipt.ownerMint(msg.sender, account, id, amount, data);
    }

    /// Exposes `IReceiptV1.ownerBurn` to anon.
    /// @param receipt The `IReceiptV1` contract to call.
    /// @param account As per `IReceiptV1.ownerBurn`.
    /// @param id As per `IReceiptV1.ownerBurn`.
    /// @param amount As per `IReceiptV1.ownerBurn`.
    /// @param receiptInformation As per `IReceiptV1.ownerBurn`.
    function ownerBurn(IReceiptV1 receipt, address account, uint256 id, uint256 amount, bytes memory receiptInformation)
        external
    {
        receipt.ownerBurn(msg.sender, account, id, amount, receiptInformation);
    }

    /// Exposes `IReceiptV1.ownerTransferFrom` to anon.
    /// @param receipt The `IReceiptV1` contract to call.
    /// @param from As per `IReceiptV1.ownerTransferFrom`.
    /// @param to As per `IReceiptV1.ownerTransferFrom`.
    /// @param id As per `IReceiptV1.ownerTransferFrom`.
    /// @param amount As per `IReceiptV1.ownerTransferFrom`.
    /// @param data As per `IReceiptV1.ownerTransferFrom`.
    function ownerTransferFrom(
        IReceiptV1 receipt,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        receipt.ownerTransferFrom(from, to, id, amount, data);
    }
}
