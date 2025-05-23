// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnerFreezable, IOwnerFreezableV1} from "src/abstract/OwnerFreezable.sol";
import {MathUpgradeable as Math} from "openzeppelin-contracts-upgradeable/contracts/utils/math/MathUpgradeable.sol";

abstract contract OwnerFreezableOwnerFreezeUntilTest is Test {
    using Math for uint256;

    IOwnerFreezableV1 internal sOwnerFreezable;
    address internal sAlice;
    address internal sBob;

    function checkOwnerFreezeUntil(uint256 freezeUntil, uint256 expectedFreeze) internal {
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(sAlice, freezeUntil, expectedFreeze);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), expectedFreeze);
    }

    function testOwnerIsAlice() external {
        assertEq(sOwnerFreezable.owner(), sAlice);
    }

    function testOwnerFreezableOnlyOwnerCanFreeze(uint256 freezeUntil) external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), 0);

        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(sAlice, freezeUntil, freezeUntil);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), freezeUntil);
    }

    /// Freezing the contract emits an event.
    function testOwnerFreezableFreezingEmitsEvent(uint256 freezeUntil) external {
        checkOwnerFreezeUntil(freezeUntil, freezeUntil);
    }

    /// Freezing twice increases the freeze until time if the second time is equal
    /// or greater than the first.
    function testOwnerFreezableFreezingIncrement(uint256 a, uint256 b) external {
        b = bound(b, a, type(uint256).max);
        checkOwnerFreezeUntil(a, a);
        checkOwnerFreezeUntil(b, b);
    }

    /// Freezing twice is a noop if the second time is less than or equal to the first.
    function testOwnerFreezableFreezingDecrement(uint256 a, uint256 b) external {
        b = bound(b, 0, a);
        checkOwnerFreezeUntil(a, a);
        checkOwnerFreezeUntil(b, a);
    }

    /// Freezing many times works if all times increase.
    function testOwnerFreezableFreezingManyIncreasing(uint32[] memory times) external {
        uint256 freezeUntil = 0;
        for (uint256 i; i < times.length; i++) {
            freezeUntil += times[i];
            checkOwnerFreezeUntil(freezeUntil, freezeUntil);
        }
    }

    /// Freezing times in the past are noops.
    function testOwnerFreezableFreezingMany(uint256[] memory freezeUntils) external {
        uint256 highwater = 0;
        for (uint256 i; i < freezeUntils.length; i++) {
            highwater = freezeUntils[i].max(highwater);
            checkOwnerFreezeUntil(freezeUntils[i], highwater);
        }
    }

    /// Only owner can call ownerFreezeAlwaysAllowFrom.
    function testOwnerFreezableOnlyOwnerCanFreezeAlwaysAllowFrom(address from, uint256 protectUntil) external {
        vm.assume(protectUntil != 0);
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from), 0);

        vm.prank(sAlice);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, protectUntil);
        assertEq(sOwnerFreezable.ownerFreezeAlwaysAllowedFrom(from), protectUntil);
    }

    /// Calling ownerFreezeAlwaysAllowFrom with a zero protectUntil reverts.
    function testOwnerFreezableZeroProtectUntilReverts(address from) external {
        vm.expectRevert(abi.encodeWithSignature("OwnerFreezeAlwaysAllowedFromZero(address)", from));
        vm.prank(sAlice);
        sOwnerFreezable.ownerFreezeAlwaysAllowFrom(from, 0);
    }
}
