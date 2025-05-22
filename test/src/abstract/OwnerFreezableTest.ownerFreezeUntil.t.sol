// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OwnerFreezableOwnerFreezeUntilTest} from "test/abstract/OwnerFreezableOwnerFreezeUntilTest.sol";
import {OwnerFreezable, IOwnerFreezableV1} from "src/abstract/OwnerFreezable.sol";

contract TestOwnerFreezable is OwnerFreezable {
    constructor() {
        _transferOwnership(msg.sender);
    }
}

contract OwnerFreezableTestOwnerFreezeUntil is OwnerFreezableOwnerFreezeUntilTest {
    constructor() {
        sAlice = address(123456);
        sBob = address(56789);
        vm.prank(sAlice);
        sOwnerFreezable = new TestOwnerFreezable();
    }
}
