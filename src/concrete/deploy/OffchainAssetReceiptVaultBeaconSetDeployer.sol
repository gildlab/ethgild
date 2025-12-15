// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt, ICLONEABLE_V2_SUCCESS} from "../receipt/Receipt.sol";
import {OffchainAssetReceiptVault, OffchainAssetReceiptVaultConfigV2} from "../vault/OffchainAssetReceiptVault.sol";
import {IBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {
    ZeroReceiptImplementation,
    ZeroVaultImplementation,
    ZeroBeaconOwner,
    InitializeNonZeroReceipt,
    InitializeReceiptFailed,
    InitializeVaultFailed
} from "../../error/ErrDeployer.sol";

struct OffchainAssetReceiptVaultBeaconSetDeployerConfig {
    address initialOwner;
    Receipt initialReceiptImplementation;
    OffchainAssetReceiptVault initialOffchainAssetReceiptVaultImplementation;
}

contract OffchainAssetReceiptVaultBeaconSetDeployer {
    event Deployment(address sender, address receiptBeacon, address offchainAssetReceiptVaultBeacon);

    IBeacon public immutable I_RECEIPT_BEACON;
    IBeacon public immutable I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON;

    constructor(OffchainAssetReceiptVaultBeaconSetDeployerConfig memory config) {
        if (address(config.initialReceiptImplementation) == address(0)) {
            revert ZeroReceiptImplementation();
        }
        if (address(config.initialOffchainAssetReceiptVaultImplementation) == address(0)) {
            revert ZeroVaultImplementation();
        }

        I_RECEIPT_BEACON = new UpgradeableBeacon(address(config.initialReceiptImplementation), config.initialOwner);
        I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON =
            new UpgradeableBeacon(address(config.initialOffchainAssetReceiptVaultImplementation), config.initialOwner);
    }

    function newOffchainAssetReceiptVault(OffchainAssetReceiptVaultConfigV2 memory config)
        external
        returns (OffchainAssetReceiptVault)
    {
        if (config.receiptVaultConfig.receipt != address(0)) {
            revert InitializeNonZeroReceipt(config.receiptVaultConfig.receipt);
        }

        if (config.initialAdmin == address(0)) revert ZeroBeaconOwner();

        Receipt receipt = Receipt(address(new BeaconProxy(address(I_RECEIPT_BEACON), "")));
        OffchainAssetReceiptVault offchainAssetReceiptVault = OffchainAssetReceiptVault(
            payable(address(new BeaconProxy(address(I_OFFCHAIN_ASSET_RECEIPT_VAULT_BEACON), "")))
        );

        if (receipt.initialize(abi.encode(offchainAssetReceiptVault)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeReceiptFailed();
        }

        config.receiptVaultConfig.receipt = address(receipt);
        if (offchainAssetReceiptVault.initialize(abi.encode(config)) != ICLONEABLE_V2_SUCCESS) {
            revert InitializeVaultFailed();
        }

        emit Deployment(msg.sender, address(receipt), address(offchainAssetReceiptVault));

        return offchainAssetReceiptVault;
    }
}
