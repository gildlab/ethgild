// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

import "./Gildable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ERC20Gild is Gildable {
    using SafeERC20 for IERC20;
    IERC20 public immutable token;

    constructor(address token_, GildConfig memory config_) Gildable(config_) {
        token = IERC20(token_);
    }

    function ungild(uint256 price_, uint256 erc1155Amount_) external {
        uint256 amount_ = _ungild(price_, erc1155Amount_);
        token.safeTransfer(msg.sender, amount_);
    }

    /// Gilds received ETH for equal parts ETHg erc20 and erc1155 tokens.
    /// Set the ETH value in the transaction as the sender to gild that ETH.
    function gild(uint256 amount_) external returns (uint256) {
        uint price_ = _gild(amount_);
        token.safeTransferFrom(msg.sender, address(this), amount_);
        return price_;
    }
}
