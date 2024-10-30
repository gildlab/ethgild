// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {TestReceipt} from "test/concrete/TestReceipt.sol";

contract TestReceiptFactory {
    ICloneableFactoryV2 public immutable factory;
    address public immutable receiptImplementation;

    /// @notice Initialize the factory and receipt implementation addresses
    /// @param _factory The address of the CloneFactory contract
    /// @param _receiptImplementation The address of the implementation for TestReceipt
    constructor(address _factory, address _receiptImplementation) {
        factory = ICloneableFactoryV2(_factory);
        receiptImplementation = _receiptImplementation;
    }

    /// @notice Creates a new TestReceipt clone with the specified owner
    /// @param owner The address to set as the owner of the new TestReceipt
    /// @return The address of the newly created TestReceipt clone
    function createReceipt(address owner) external returns (TestReceipt) {
        // Clone TestReceipt using the factory
        address clone = factory.clone(receiptImplementation, abi.encode(owner));

        // Return the clone cast to TestReceipt type
        return TestReceipt(clone);
    }
}
