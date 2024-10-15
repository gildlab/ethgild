// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Vm} from "forge-std/Test.sol";

library LibUniqueAddressesGenerator {
    // Generates two unique addresses from the provided fuzzed keys
    function generateUniqueAddresses(Vm vm, uint256 SECP256K1_ORDER, uint256 fuzzedKeyAlice, uint256 fuzzedKeyBob)
        internal
        pure
        returns (address, address)
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        return (alice, bob);
    }

    // Generates unique addresses from the provided fuzzed keys
    function generateUniqueAddresses(Vm vm, uint256 SECP256K1_ORDER, uint256[] memory fuzzedKeys)
        internal
        pure
        returns (address[] memory addresses)
    {
        // Ensure the fuzzed keys are within the valid range for secp256k1
        uint256 length = fuzzedKeys.length;
        addresses = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            address generatedAddress = vm.addr((fuzzedKeys[i] % (SECP256K1_ORDER - 1)) + 1);
            addresses[i] = generatedAddress;
        }

        // Check for uniqueness
        for (uint256 i = 0; i < length; i++) {
            for (uint256 j = i + 1; j < length; j++) {
                vm.assume(addresses[i] != addresses[j]);
            }
        }

        return addresses; // Returning the array of addresses
    }
}
