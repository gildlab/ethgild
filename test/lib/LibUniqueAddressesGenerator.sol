// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";

library LibUniqueAddressesGenerator {
    function generateUniqueAddress(Vm vm, uint256 SECP256K1_ORDER, uint256 keySeed) internal pure returns (address) {
        // Ensure the fuzzed key is within the valid range for secp256k1
        return vm.addr((keySeed % (SECP256K1_ORDER - 1)) + 1);
    }

    // Generates two unique addresses from the provided fuzzed keys
    function generateUniqueAddresses(Vm vm, uint256 SECP256K1_ORDER, uint256 aliceKey, uint256 bobKey)
        internal
        pure
        returns (address, address)
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);
        address bob = generateUniqueAddress(vm, SECP256K1_ORDER, bobKey);
        vm.assume(alice != bob);

        return (alice, bob);
    }
}
