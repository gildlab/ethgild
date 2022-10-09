// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.15;

import {IERC1155Upgradeable as IERC1155} from "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

interface IReceipt is IERC1155 {
       function ownerMint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function ownerBurn(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function ownerTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function receiptInformation(uint256 id, bytes memory data) external;
}