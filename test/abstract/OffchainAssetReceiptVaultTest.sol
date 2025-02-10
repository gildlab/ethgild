// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfig
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibOffchainAssetVaultCreator} from "../lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultTest is Test {
    event OffchainAssetReceiptVaultInitializedV2(address sender, OffchainAssetReceiptVaultConfigV2 config);

    ICloneableFactoryV2 internal immutable iFactory;
    OffchainAssetReceiptVault internal immutable iImplementation;
    OffchainAssetReceiptVaultAuthorizorV1 internal immutable iAuthorizorImplementation;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
        iImplementation = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: receiptImplementation})
        );
        iAuthorizorImplementation = new OffchainAssetReceiptVaultAuthorizorV1();
    }

    function createVault(address admin, string memory name, string memory symbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        return LibOffchainAssetVaultCreator.createVault(
            vm, iFactory, iImplementation, iAuthorizorImplementation, admin, name, symbol
        );
    }

    function getReceipt(Vm.Log[] memory logs) internal pure returns (ReceiptContract) {
        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == OffchainAssetReceiptVaultInitializedV2.selector) {
                // Decode the event data
                (, OffchainAssetReceiptVaultConfigV2 memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfigV2));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }
}
