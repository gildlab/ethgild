// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.17;

interface IReceiptOwner {
    function authorizeReceiptTransfer(address from, address to) external view;

    function authorizeReceiptInformation(
        address account,
        uint256 id,
        bytes memory data
    ) external view;
}
