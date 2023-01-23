// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../vault/receipt/IReceiptV1.sol";
import "../vault/receipt/IReceiptOwnerV1.sol";

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
    address internal from;
    /// The address that is authorized to receive transfers.
    address internal to;

    /// Anon can set the from address.
    /// @param from_ The new `from` address.
    function setFrom(address from_) external {
        from = from_;
    }

    /// Anon can set the to address.
    /// @param to_ The new `to` address.
    function setTo(address to_) external {
        to = to_;
    }

    /// Only transfers between `from` and `to` are authorized.
    /// @inheritdoc IReceiptOwnerV1
    function authorizeReceiptTransfer(
        address from_,
        address to_
    ) external view {
        if (from_ != from) {
            revert UnauthorizedTransfer(from_, to_);
        }
        if (to_ != to) {
            revert UnauthorizedTransfer(from_, to_);
        }
    }

    /// Exposes `IReceiptV1.ownerMint` to anon.
    /// @param receipt_ The `IReceiptV1` contract to call.
    /// @param account_ As per `IReceiptV1.ownerMint`.
    /// @param id_ As per `IReceiptV1.ownerMint`.
    /// @param amount_ As per `IReceiptV1.ownerMint`.
    /// @param data_ As per `IReceiptV1.ownerMint`.
    function ownerMint(
        IReceiptV1 receipt_,
        address account_,
        uint256 id_,
        uint256 amount_,
        bytes memory data_
    ) external {
        receipt_.ownerMint(account_, id_, amount_, data_);
    }

    /// Exposes `IReceiptV1.ownerBurn` to anon.
    /// @param receipt_ The `IReceiptV1` contract to call.
    /// @param account_ As per `IReceiptV1.ownerBurn`.
    /// @param id_ As per `IReceiptV1.ownerBurn`.
    /// @param amount_ As per `IReceiptV1.ownerBurn`.
    /// @param receiptInformation_ As per `IReceiptV1.ownerBurn`.
    function ownerBurn(
        IReceiptV1 receipt_,
        address account_,
        uint256 id_,
        uint256 amount_,
        bytes memory receiptInformation_
    ) external {
        receipt_.ownerBurn(account_, id_, amount_, receiptInformation_);
    }

    /// Exposes `IReceiptV1.ownerTransferFrom` to anon.
    /// @param receipt_ The `IReceiptV1` contract to call.
    /// @param from_ As per `IReceiptV1.ownerTransferFrom`.
    /// @param to_ As per `IReceiptV1.ownerTransferFrom`.
    /// @param id_ As per `IReceiptV1.ownerTransferFrom`.
    /// @param amount_ As per `IReceiptV1.ownerTransferFrom`.
    /// @param data_ As per `IReceiptV1.ownerTransferFrom`.
    function ownerTransferFrom(
        IReceiptV1 receipt_,
        address from_,
        address to_,
        uint256 id_,
        uint256 amount_,
        bytes memory data_
    ) external {
        receipt_.ownerTransferFrom(from_, to_, id_, amount_, data_);
    }
}
