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
}
