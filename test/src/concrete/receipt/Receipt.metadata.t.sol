// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";

contract ReceiptMetadataTest is Test {
    function testReceiptURI(uint256 id) external {
        id = bound(id, 0, uint256(type(uint128).max));
        TestReceipt receipt = new TestReceipt();

        string memory uri = receipt.uri(0.01544e18);
    }
}
