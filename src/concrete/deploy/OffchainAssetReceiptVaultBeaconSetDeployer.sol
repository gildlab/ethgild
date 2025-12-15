// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt, ICLONEABLE_V2_SUCCESS} from "../receipt/Receipt.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfigV2} from "../vault/OffchainAssetReceiptVault.sol";
import {IBeacon, UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

struct OffchainAssetReceiptVaultBeaconSetDeployerConfig {
    address initialOwner;
    Receipt initialReceiptImplementation;
    OffchainAssetReceiptVault initialOffchainAssetReceiptVaultImplementation;
}

contract OffchainAssetReceiptVaultBeaconSetDeployer {
    IBeacon public immutable I_RECEIPT_BEACON;
    IBeacon public immutable I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON;

    constructor(OffchainAssetReceiptVaultBeaconSetDeployerConfig memory config) {
        I_RECEIPT_BEACON = new UpgradeableBeacon(address(config.initialReceiptImplementation), config.initialOwner);
        I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON =
            new UpgradeableBeacon(address(config.initialOffchainAssetReceiptVaultImplementation), config.initialOwner);
    }

    function newOffchainAssetReceiptVault(OffchainAssetReceiptVaultConfigV2 memory config)
        external
        returns (OffchainAssetReceiptVault)
    {
        require(config.receiptVaultConfig.receipt == address(0), "Receipt address must be zero");

        Receipt receipt = Receipt(address(new BeaconProxy(address(I_RECEIPT_BEACON), "")));
        OffchainAssetReceiptVault offchainAssetReceiptVault = OffchainAssetReceiptVault(
            payable(address(new BeaconProxy(address(I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON), "")))
        );

        require(
            receipt.initialize(abi.encode(offchainAssetReceiptVault)) == ICLONEABLE_V2_SUCCESS, "Failed to init receipt"
        );

        config.receiptVaultConfig.receipt = address(receipt);
        require(
            offchainAssetReceiptVault.initialize(abi.encode(config)) == ICLONEABLE_V2_SUCCESS,
            "Failed to init offchain asset receipt vault"
        );

        return offchainAssetReceiptVault;
    }
}
