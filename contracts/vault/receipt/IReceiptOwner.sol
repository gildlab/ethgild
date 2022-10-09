// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.15;

interface IReceiptOwner {
    function authorizeReceiptTransfer(address from, address to) external view;

    function authorizeReceiptInformation(uint256 id, bytes memory data)
        external
        view;
}
