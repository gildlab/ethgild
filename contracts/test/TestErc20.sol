// SPDX-License-Identifier: MIT
pragma solidity =0.8.15;

import {ERC20Upgradeable as ERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

// solhint-disable-next-line max-line-length

/// @title Erc20Token
/// A test token that can be used as a reserve asset.

contract TestErc20 is ERC20 {
    /// Accounts to freeze during testing.

    // Stables such as USDT and USDC commonly have 6 decimals.
    uint256 public constant DECIMALS = 6;
    // One _billion_ dollars 👷😈.
    uint256 public constant TOTAL_SUPPLY = 10**(DECIMALS + 9);

    /// Define and mint the erc20 token.
    constructor() initializer {
        __ERC20_init("USD Classic", "USDCC");
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
