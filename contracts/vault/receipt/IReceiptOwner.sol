// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.15;

interface IReceiptOwner {
    function authorizeReceiptTransfer(address from_, address to_) external view;
}