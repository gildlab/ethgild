// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

interface IReceiptAuthority {
    function authorizeMint(address sender, address account, uint256 id, uint256 amount) external view;

    function authorizeBurn(address sender, address account, uint256 id, uint256 amount) external view;

    function authorizeTransferFrom(address sender, address from, address to) external view;

    function authorizeReceiptInformation(
        address account,
        uint256 id,
        bytes memory data
    ) external view;
}
