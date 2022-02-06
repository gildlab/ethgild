// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

abstract contract IPriceOracle {
    function price() external virtual view returns (uint256);
}