// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.12;

import "./Gildable.sol";

contract NativeGild is Gildable {
    // solhint-disable-next-line no-empty-blocks
    constructor(GildConfig memory config_) Gildable(config_) {}

    /// Overburn ETHg at 1001:1000 ratio to receive initial ETH refund.
    /// If the `msg.sender` does not have _both_ the erc1155 and erc20 balances
    /// for a given reference price the ETH will not ungild. The erc20 and
    /// erc1155 amounts as `xauReferencePrice * ethAmount` (+0.1% for erc20)
    /// will be burned.
    /// @param price_ oracle price in Native asset. MUST correspond
    /// to an erc1155 balance held by `msg.sender`.
    /// @param erc1155Amount_ the amount of ETH to ungild.
    function ungild(uint256 price_, uint256 erc1155Amount_) external {
        uint256 amount_ = _ungild(price_, erc1155Amount_);
        // solhint-disable-next-line avoid-low-level-calls
        (bool refundSuccess_, ) = msg.sender.call{value: amount_}("");
        require(refundSuccess_, "UNGILD_ETH");
    }

    /// Gilds received ETH for equal parts ETHg erc20 and erc1155 tokens.
    /// Set the ETH value in the transaction as the sender to gild that ETH.
    function gild() external payable returns (uint256) {
        return _gild(msg.value);
    }
}
