// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {IERC1155Upgradeable as IERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

/// @title IReceipt
/// @notice IReceipt is an extension to IERC1155 that exposes minting, burning,
/// forced transfer and emitting `ReceiptInformation` events. ONLY the owner
interface IReceipt is IERC1155 {
    /// Emitted when new information is provided for a receipt.
    /// @param sender `msg.sender` emitting the information for the receipt.
    /// @param id Receipt the information is for.
    /// @param information Information for the receipt. MAY reference offchain
    /// data where the payload is large.
    event ReceiptInformation(address sender, uint256 id, bytes information);

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function burn(address account, uint256 id, uint256 amount) external;

    function receiptInformation(uint256 id, bytes memory data) external;
}
