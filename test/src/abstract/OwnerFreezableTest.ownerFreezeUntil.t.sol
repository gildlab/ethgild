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

contract OwnerFreezableTestOwnerFreeUntil is Test {
    /// Only the owner can freeze the contract.
    function testOwnerFreezableOnlyOwnerCanFreeze(address alice, address bob, uint256 freezeUntil) public {
        vm.assume(alice != bob);
        vm.prank(alice);
        TestOwnerFreezable ownerFreezable = new TestOwnerFreezable();
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(bob);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(ownerFreezable.ownerFrozenUntil(), 0);

        vm.prank(alice);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(ownerFreezable.ownerFrozenUntil(), freezeUntil);
    }

    /// Freezing the contract emits an event.
    function testOwnerFreezableFreezingEmitsEvent(address alice, uint256 freezeUntil) public {
        vm.assume(alice != address(0));
        vm.prank(alice);
        TestOwnerFreezable ownerFreezable = new TestOwnerFreezable();
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(alice, freezeUntil);
        vm.prank(alice);
        ownerFreezable.ownerFreezeUntil(freezeUntil);
    }
}
