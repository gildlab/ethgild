// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IReceiptOwnerV1 {
    function authorizeReceiptTransfer(address from, address to) external view;

    function authorizeReceiptInformation(
        address account,
        uint256 id,
        bytes memory data
    ) external view;
}
