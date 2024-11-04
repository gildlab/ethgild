// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {ReceiptFactoryTest} from "../abstract/ReceiptFactoryTest.sol";
import {Receipt} from "src/concrete/receipt/Receipt.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";

library LibReceiptCreator {
    /// Helper to create child receipt.
    function createReceipt(ICloneableFactoryV2 factory, Receipt receiptImplementation, address owner)
        internal
        returns (TestReceipt)
    {
        // Clone TestReceipt using the factory and initialize it with the owner
        address clone = factory.clone(address(receiptImplementation), abi.encode(owner));
        // Return the clone cast to TestReceipt type
        return TestReceipt(clone);
    }
}
