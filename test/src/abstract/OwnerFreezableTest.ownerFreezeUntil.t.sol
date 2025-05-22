// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnerFreezable, IOwnerFreezableV1} from "src/abstract/OwnerFreezable.sol";

contract TestOwnerFreezable is OwnerFreezable {
    constructor() {
        _transferOwnership(msg.sender);
    }
}

contract OwnerFreezableTestOwnerFreezeUntil is Test {
    function checkOwnerFreezableOnlyOwnerCanFreeze(
        IOwnerFreezableV1 ownerFreezable,
        address alice,
        address bob,
        uint256 freezeUntil
    ) internal {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(ownerFreezable.ownerFrozenUntil(), 0);

        vm.prank(alice);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(ownerFreezable.ownerFrozenUntil(), freezeUntil);
    }

    /// Only the owner can freeze the contract.
    function testOwnerFreezableOnlyOwnerCanFreeze(address alice, address bob, uint256 freezeUntil) external {
        vm.assume(alice != bob);
        vm.prank(alice);

        TestOwnerFreezable ownerFreezable = new TestOwnerFreezable();
        checkOwnerFreezableOnlyOwnerCanFreeze(ownerFreezable, alice, bob, freezeUntil);
    }

    /// Freezing the contract emits an event.
    function testOwnerFreezableFreezingEmitsEvent(address alice, uint256 freezeUntil) external {
        vm.assume(alice != address(0));
        vm.prank(alice);
        TestOwnerFreezable ownerFreezable = new TestOwnerFreezable();
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(alice, freezeUntil);
        vm.prank(alice);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
    }

    /// Freezing many times works if all times increase.
    function testOwnerFreezableFreezingManyIncreasing(uint32[] memory times) external {
        TestOwnerFreezable ownerFreezable = new TestOwnerFreezable();

        uint256 freezeUntil = 0;
        for (uint256 i; i < times.length; i++) {
            freezeUntil += times[i];

            ownerFreezable.ownerFreezeUntil(freezeUntil);
            assertEq(ownerFreezable.ownerFrozenUntil(), freezeUntil);
        }
    }
}
