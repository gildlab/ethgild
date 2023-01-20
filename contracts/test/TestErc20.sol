// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import {ERC20Upgradeable as ERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/// @dev One _billion_ dollars 👷😈 is 18 + 9 decimals.
uint256 constant TOTAL_SUPPLY = 1e27;
/// @dev The name is arbitrary for testing.
string constant NAME = "Token";
/// @dev The symbol is arbitrary for testing.
string constant SYMBOL = "TKN";

/// @title Erc20Token
/// @notice A test token that can be used as a vault asset.
contract TestErc20 is ERC20 {
    /// Define and mint the erc20 token.
    constructor() initializer {
        __ERC20_init(NAME, SYMBOL);
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
