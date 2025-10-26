// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfigV2
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibOffchainAssetVaultCreator} from "../lib/LibOffchainAssetVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable I_FACTORY;
    OffchainAssetReceiptVault internal immutable I_IMPLEMENTATION;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable I_AUTHORIZER_IMPLEMENTATION;
    ReceiptContract internal immutable I_RECEIPT_IMPLEMENTATION;

    constructor() {
        I_FACTORY = new CloneFactory();
        I_RECEIPT_IMPLEMENTATION = new ReceiptContract();
        I_IMPLEMENTATION = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: I_FACTORY, receiptImplementation: I_RECEIPT_IMPLEMENTATION})
        );
        I_AUTHORIZER_IMPLEMENTATION = new OffchainAssetReceiptVaultAuthorizerV1();
    }

    function createVault(address admin, string memory shareName, string memory shareSymbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        return LibOffchainAssetVaultCreator.createVault(
            vm, I_FACTORY, I_IMPLEMENTATION, I_AUTHORIZER_IMPLEMENTATION, admin, shareName, shareSymbol
        );
    }

    function getReceipt(Vm.Log[] memory logs) internal pure returns (ReceiptContract) {
        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == OffchainAssetReceiptVault.OffchainAssetReceiptVaultInitializedV2.selector) {
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
