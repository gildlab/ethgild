// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {Test} from "forge-std/Test.sol";
import {OwnableOracle} from "contracts/concrete/OwnableOracle.sol";

contract OwnableOracleTest is Test {
    event Price(uint256 oldPrice, uint256 newPrice);

    /// The owner can set the price.
    /// Anon can't set the price.
    function testSetPrice(uint256 ownerSeed, uint256 anonSeed, uint256 newPrice0, uint256 newPrice1) external {
        vm.assume(ownerSeed != anonSeed);
        address owner = vm.addr((ownerSeed % (SECP256K1_ORDER - 1)) + 1);
        address anon = vm.addr((anonSeed % (SECP256K1_ORDER - 1)) + 1);

        vm.prank(owner);
        OwnableOracle oracle = new OwnableOracle();

        assertEq(oracle.price(), 0);

        // Anon can't set the price.
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(anon);
        oracle.setPrice(newPrice0);

        assertEq(oracle.price(), 0);

        // Owner can set the price.
        vm.expectEmit(false, false, false, true);
        emit Price(0, newPrice0);
        vm.prank(owner);
        oracle.setPrice(newPrice0);

        assertEq(oracle.price(), newPrice0);

        // Anon can't set the price.
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(anon);
        oracle.setPrice(newPrice1);

        assertEq(oracle.price(), newPrice0);

        // Owner can set the price again.
        vm.expectEmit(false, false, false, true);
        emit Price(newPrice0, newPrice1);
        vm.prank(owner);
        oracle.setPrice(newPrice1);

        assertEq(oracle.price(), newPrice1);

        // Anon can't set the price.
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(anon);
        oracle.setPrice(newPrice0);
    }
}
