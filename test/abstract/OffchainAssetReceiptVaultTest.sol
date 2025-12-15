// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVault,
    ReceiptVaultConfigV2
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "../../src/concrete/receipt/Receipt.sol";
import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "../../src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {
    OffchainAssetReceiptVaultBeaconSetDeployer,
    OffchainAssetReceiptVaultBeaconSetDeployerConfig
} from "../../src/concrete/deploy/OffchainAssetReceiptVaultBeaconSetDeployer.sol";
import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";

contract OffchainAssetReceiptVaultTest is Test {
    OffchainAssetReceiptVault internal immutable I_IMPLEMENTATION;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable I_AUTHORIZER_IMPLEMENTATION;
    ReceiptContract internal immutable I_RECEIPT_IMPLEMENTATION;
    OffchainAssetReceiptVaultBeaconSetDeployer internal immutable I_DEPLOYER;

    constructor() {
        I_RECEIPT_IMPLEMENTATION = new ReceiptContract();
        I_IMPLEMENTATION = new OffchainAssetReceiptVault();
        I_AUTHORIZER_IMPLEMENTATION = new OffchainAssetReceiptVaultAuthorizerV1();
        I_DEPLOYER = new OffchainAssetReceiptVaultBeaconSetDeployer(
            OffchainAssetReceiptVaultBeaconSetDeployerConfig({
                initialOwner: address(this),
                initialReceiptImplementation: I_RECEIPT_IMPLEMENTATION,
                initialOffchainAssetReceiptVaultImplementation: I_IMPLEMENTATION
            })
        );
    }

    function createVault(address admin, string memory shareName, string memory shareSymbol)
        internal
        returns (OffchainAssetReceiptVault)
    {
        OffchainAssetReceiptVault vault = I_DEPLOYER.newOffchainAssetReceiptVault(
            OffchainAssetReceiptVaultConfigV2({
                initialAdmin: admin,
                receiptVaultConfig: ReceiptVaultConfigV2({
                    asset: address(0),
                    name: shareName,
                    symbol: shareSymbol,
                    receipt: address(0)
                })
            })
        );
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(Clones.clone(address(I_AUTHORIZER_IMPLEMENTATION)));
        vm.startPrank(admin);
        authorizer.initialize(abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: admin})));
        vault.setAuthorizer(authorizer);
        vm.stopPrank();
        return vault;
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
