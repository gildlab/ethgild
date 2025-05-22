// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {OwnerFreezable, IOwnerFreezableV1} from "src/abstract/OwnerFreezable.sol";

abstract contract OwnerFreezableOwnerFreezeUntilTest is Test {
    IOwnerFreezableV1 internal sOwnerFreezable;
    address internal sAlice;
    address internal sBob;

    function testOwnerFreezableOnlyOwnerCanFreeze(uint256 freezeUntil) external {
        vm.expectRevert("Ownable: caller is not the owner");
        vm.prank(sBob);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), 0);

        vm.prank(sAlice);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
        assertEq(sOwnerFreezable.ownerFrozenUntil(), freezeUntil);
    }

    /// Freezing the contract emits an event.
    function testOwnerFreezableFreezingEmitsEvent(uint256 freezeUntil) external {
        vm.prank(sAlice);
        vm.expectEmit(true, true, true, true);
        emit IOwnerFreezableV1.OwnerFrozenUntil(sAlice, freezeUntil);
        sOwnerFreezable.ownerFreezeUntil(freezeUntil);
    }

    /// Freezing many times works if all times increase.
    function testOwnerFreezableFreezingManyIncreasing(uint32[] memory times) external {
        uint256 freezeUntil = 0;
        for (uint256 i; i < times.length; i++) {
            freezeUntil += times[i];

            vm.prank(sAlice);
            sOwnerFreezable.ownerFreezeUntil(freezeUntil);
            assertEq(sOwnerFreezable.ownerFrozenUntil(), freezeUntil);
        }
    }
}
