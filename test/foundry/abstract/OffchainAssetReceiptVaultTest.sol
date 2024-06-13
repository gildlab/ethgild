// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfig
} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibOffchainAssetVaultCreator} from "../lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";

contract OffchainAssetReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    OffchainAssetReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
        iImplementation = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: receiptImplementation})
        );
    }

    function createVault(address admin, string memory name, string memory symbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        return LibOffchainAssetVaultCreator.createVault(iFactory, iImplementation, admin, name, symbol);
    }
}
