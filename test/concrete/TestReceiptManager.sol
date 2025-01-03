// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IReceiptV2} from "src/interface/IReceiptV2.sol";
import {IReceiptManagerV1} from "src/interface/IReceiptManagerV1.sol";

/// Thrown when a transfer is not authorized.
/// @param from The transfer attempted from this address.
/// @param to The transfer attemped to this address.
error UnauthorizedTransfer(address from, address to);

contract TestReceiptManagerAsset {
    function symbol() external pure returns (string memory) {
        return "TRMAsset";
    }

    function name() external pure returns (string memory) {
        return "TestReceiptManagerAsset";
    }
}

/// @title TestReceiptManager
/// @notice TEST contract that can be the manager of an `IReceiptV2` and forward
/// function calls to the manager restricted functions on the receipt. Completely
/// insecure, intended for use only by the test harness to drive tests.
contract TestReceiptManager is IReceiptManagerV1 {
    /// The address of the test asset.
    address internal iAsset;

    /// The address that is authorized to send transfers.
    address internal sFrom;
    /// The address that is authorized to receive transfers.
    address internal sTo;

    constructor() {
        iAsset = address(new TestReceiptManagerAsset());
    }

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
    /// @inheritdoc IReceiptManagerV1
    function authorizeReceiptTransfer2(address from, address to) external view {
        if (from != sFrom) {
            revert UnauthorizedTransfer(from, to);
        }
        if (to != sTo) {
            revert UnauthorizedTransfer(from, to);
        }
    }

    /// Exposes `IReceiptV2.managerMint` to anon.
    /// @param receipt The `IReceiptV2` contract to call.
    /// @param account As per `IReceiptV2.managerMint`.
    /// @param id As per `IReceiptV2.managerMint`.
    /// @param amount As per `IReceiptV2.managerMint`.
    /// @param data As per `IReceiptV2.managerMint`.
    function managerMint(IReceiptV2 receipt, address account, uint256 id, uint256 amount, bytes memory data) external {
        receipt.managerMint(msg.sender, account, id, amount, data);
    }

    /// Exposes `IReceiptV2.managerBurn` to anon.
    /// @param receipt The `IReceiptV2` contract to call.
    /// @param account As per `IReceiptV2.managerBurn`.
    /// @param id As per `IReceiptV2.managerBurn`.
    /// @param amount As per `IReceiptV2.managerBurn`.
    /// @param receiptInformation As per `IReceiptV2.managerBurn`.
    function managerBurn(
        IReceiptV2 receipt,
        address account,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation
    ) external {
        receipt.managerBurn(msg.sender, account, id, amount, receiptInformation);
    }

    /// Exposes `IReceiptV2.managerTransferFrom` to anon.
    /// @param receipt The `IReceiptV2` contract to call.
    /// @param from As per `IReceiptV2.managerTransferFrom`.
    /// @param to As per `IReceiptV2.managerTransferFrom`.
    /// @param id As per `IReceiptV2.managerTransferFrom`.
    /// @param amount As per `IReceiptV2.managerTransferFrom`.
    /// @param data As per `IReceiptV2.managerTransferFrom`.
    function managerTransferFrom(
        IReceiptV2 receipt,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external {
        receipt.managerTransferFrom(from, to, id, amount, data);
    }

    function name() external pure returns (string memory) {
        return "TestReceiptManager";
    }

    function symbol() external pure returns (string memory) {
        return "TRM";
    }

    function asset() external view returns (address) {
        return iAsset;
    }
}
