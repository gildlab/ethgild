// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
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

    /// @notice Creates a new ReceiptContract clone with the specified owner
    /// @param owner The address to set as the owner of the new ReceiptContract
    /// @return The address of the newly created ReceiptContract clone
    function createReceipt(address manager, address owner) internal returns (ReceiptContract) {
        // Clone ReceiptContract using the factory and initialize it with the owner
        address clone = iFactory.clone(
            address(receiptImplementation), abi.encode(ReceiptConfigV1{receiptManager: manager, receiptOwner: owner})
        );
        // Return the clone cast to ReceiptContract type
        return ReceiptContract(clone);
    }
}
