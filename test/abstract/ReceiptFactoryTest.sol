// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract ReceiptFactoryTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
    }

    /// Creates a new `ReceiptContract` clone with the specified manager.
    /// @param manager The address to set as the manager of the new ReceiptContract
    /// @return The address of the newly created `ReceiptContract` clone
    function createReceipt(address manager) internal returns (ReceiptContract) {
        // Clone ReceiptContract using the factory and initialize it with the
        // owner and manager.
        address clone = iFactory.clone(address(receiptImplementation), abi.encode(manager));
        // Return the clone cast to ReceiptContract type
        return ReceiptContract(clone);
    }
}
