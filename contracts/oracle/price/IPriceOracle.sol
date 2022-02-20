// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

abstract contract IPriceOracle {
    function price() external view virtual returns (uint256);
}
