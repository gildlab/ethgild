// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract ReceiptFactoryTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
    }

    /// @notice Creates a new TestReceipt clone with the specified owner
    /// @param owner The address to set as the owner of the new TestReceipt
    /// @return The address of the newly created TestReceipt clone
    function createReceipt(address owner) internal returns (TestReceipt) {
        // Clone TestReceipt using the factory and initialize it with the owner
        address clone = iFactory.clone(address(receiptImplementation), abi.encode(owner));
        // Return the clone cast to TestReceipt type
        return TestReceipt(clone);
    }
}
