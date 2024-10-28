// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {LibFork} from "rain.flare/../test/fork/LibFork.sol";

abstract contract OracleTest is Test {
    uint256 constant BLOCK_NUMBER = 31993648;
    address constant ALICE = address(uint160(uint256(keccak256("ALICE"))));

    constructor() {
        vm.createSelectFork(LibFork.rpcUrlFlare(vm), BLOCK_NUMBER);
    }
}
