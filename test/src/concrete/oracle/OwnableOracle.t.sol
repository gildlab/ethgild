// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnableOracle} from "src/concrete/oracle/OwnableOracle.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OwnableOracleTest is Test {
    event Price(uint256 oldPrice, uint256 newPrice);

    function checkAnonCantSetPrice(OwnableOracle oracle, address anon, uint256 newPrice) internal {
        uint256 price = oracle.price();

        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(anon);
        oracle.setPrice(newPrice);

        assertEq(oracle.price(), price);
    }

    function checkOwnerCanSetPrice(OwnableOracle oracle, address owner, uint256 newPrice) internal {
        uint256 price = oracle.price();

        vm.expectEmit(false, false, false, true);
        emit Price(price, newPrice);
        vm.prank(owner);
        oracle.setPrice(newPrice);

        assertEq(oracle.price(), newPrice);
    }

    /// The owner can set the price.
    /// Anon can't set the price.
    function testSetPrice(uint256 ownerSeed, uint256 anonSeed, uint256 newPrice0, uint256 newPrice1) external {
        // Generate unique addresses
        (address owner, address anon) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, ownerSeed, anonSeed);

        vm.prank(owner);
        OwnableOracle oracle = new OwnableOracle();
        assertEq(oracle.owner(), owner);

        assertEq(oracle.price(), 0);

        checkAnonCantSetPrice(oracle, anon, newPrice0);
        checkOwnerCanSetPrice(oracle, owner, newPrice0);
        checkAnonCantSetPrice(oracle, anon, newPrice1);
        checkOwnerCanSetPrice(oracle, owner, newPrice1);
        checkAnonCantSetPrice(oracle, anon, newPrice0);
    }
}
