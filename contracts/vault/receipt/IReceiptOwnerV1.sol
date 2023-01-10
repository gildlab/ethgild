// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

/// @title IReceiptOwnerV1
/// @notice Owner of an `IReceiptV1` MUST authorize transfers and receipt
/// information calls in addition to being directly responsible for `ownerX`
/// calls.
interface IReceiptOwnerV1 {
    /// Authorise a receipt transfer. `IReceiptOwnerV1` contract MUST REVERT if
    /// the transfer is unauthorized. NOT reverting means the transfer is
    /// authorized.
    /// @param from The address the receipt is being transferred from.
    /// @param to The address the receipt is being transferred to.
    function authorizeReceiptTransfer(address from, address to) external view;

    /// Authorize emitting `ReceiptInformation`. `IReceiptOwnerV1` contract MUST
    /// REVERT if the receipt information is unauthorized. NOT reverting means
    /// the receipt information is authorized.
    /// @param account The address the receipt information is being emitted by.
    /// @param id The receipt ID the receipt information is being emitted for.
    /// @param data The receipt information data being emitted.
    function authorizeReceiptInformation(
        address account,
        uint256 id,
        bytes memory data
    ) external view;
}
