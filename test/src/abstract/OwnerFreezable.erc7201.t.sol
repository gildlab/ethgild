// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {LibERC7201} from "test/lib/LibERC7201.sol";
import {Test} from "forge-std/Test.sol";
import {OWNER_FREEZABLE_V1_STORAGE_LOCATION} from "src/abstract/OwnerFreezable.sol";

contract OwnerFreezableERC7201Test is Test {
    function testOwnerFreezableStorageLocation() external {
        bytes32 expected = LibERC7201.idForString("rain.storage.owner-freezable.1");
        bytes32 actual = OWNER_FREEZABLE_V1_STORAGE_LOCATION;
        assertEq(actual, expected);
    }
}
