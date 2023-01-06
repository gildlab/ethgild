// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC1155Upgradeable as IERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

/// @title IReceiptV1
/// @notice IReceiptV1 is an extension to IERC1155 that requires implementers to
/// provide an interface to allow an owner to ARBITRARILY:
///
/// - mint
/// - burn
/// - transfer
/// - emit data
///
/// The owner MUST implement `IReceiptOwnerV1` to authorize.
interface IReceiptV1 is IERC1155 {
    /// Emitted when new information is provided for a receipt.
    /// @param sender `msg.sender` emitting the information for the receipt.
    /// @param id Receipt the information is for.
    /// @param information Information for the receipt. MAY reference offchain
    /// data where the payload is large.
    event ReceiptInformation(address sender, uint256 id, bytes information);

    function ownerMint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function ownerBurn(address account, uint256 id, uint256 amount) external;

    function ownerTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function receiptInformation(uint256 id, bytes memory data) external;
}
