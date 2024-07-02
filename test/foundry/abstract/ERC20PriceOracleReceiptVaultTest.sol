// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConstructionConfig
} from "contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibERC20PriceOracleReceiptVaultCreator} from "../lib/LibERC20PriceOracleReceiptVaultCreator.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";
import {TestErc20} from "contracts/test/TestErc20.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: receiptImplementation})
        );
    }

    function createVault(address admin, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        TestErc20 asset = new TestErc20();
        return LibERC20PriceOracleReceiptVaultCreator.createVault(
            iFactory, iImplementation, address(asset), admin, name, symbol
        );
    }
}
