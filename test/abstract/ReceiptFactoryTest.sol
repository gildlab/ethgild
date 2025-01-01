// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {ERC20PriceOracleReceipt} from "src/concrete/receipt/ERC20PriceOracleReceipt.sol";

contract ReceiptFactoryTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ReceiptContract internal immutable iReceiptImplementation;
    ERC20PriceOracleReceipt internal immutable iERC20PriceOracleReceiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iERC20PriceOracleReceiptImplementation = new ERC20PriceOracleReceipt();
    }
}
