// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Vm} from "forge-std/Test.sol";

library LibUniqueAddressesGenerator {
    function generateUniqueAddresses(Vm vm, uint256 SECP256K1_ORDER, uint256 seed) internal pure returns (address) {
        // Ensure the fuzzed key is within the valid range for secp256k1
        return vm.addr((seed % (SECP256K1_ORDER - 1)) + 1);
    }

    // Generates two unique addresses from the provided seeds
    function generateUniqueAddresses(Vm vm, uint256 SECP256K1_ORDER, uint256 aliceSeed, uint256 bobSeed)
        internal
        pure
        returns (address, address)
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = generateUniqueAddresses(vm, SECP256K1_ORDER, aliceSeed);
        address bob = generateUniqueAddresses(vm, SECP256K1_ORDER, bobSeed);
        vm.assume(alice != bob);

        return (alice, bob);
    }

    // Generates three unique addresses from the provided seeds
    function generateUniqueAddresses(
        Vm vm,
        uint256 SECP256K1_ORDER,
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 carolSeed
    ) internal pure returns (address, address, address) {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = generateUniqueAddresses(vm, SECP256K1_ORDER, aliceSeed);
        address bob = generateUniqueAddresses(vm, SECP256K1_ORDER, bobSeed);
        address carol = generateUniqueAddresses(vm, SECP256K1_ORDER, carolSeed);
        vm.assume(alice != bob);
        vm.assume(alice != carol);
        vm.assume(bob != carol);

        return (alice, bob, carol);
    }
}
