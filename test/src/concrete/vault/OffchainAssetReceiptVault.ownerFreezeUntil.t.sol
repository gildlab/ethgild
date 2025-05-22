// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {
    OwnerFreezableOwnerFreezeUntilTest, IOwnerFreezableV1
} from "test/abstract/OwnerFreezableOwnerFreezeUntilTest.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfigV2
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {LibOffchainAssetVaultCreator} from "../../../lib/LibOffchainAssetVaultCreator.sol";

contract OffchainAssetReceiptVaultOwnerFreezeUntilTest is OwnerFreezableOwnerFreezeUntilTest {
    ICloneableFactoryV2 internal immutable iFactory;
    OffchainAssetReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable iReceiptImplementation;
    OffchainAssetReceiptVaultAuthorizerV1 internal immutable iAuthorizerImplementation;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iImplementation = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: iFactory, receiptImplementation: iReceiptImplementation})
        );
        iAuthorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        sAlice = address(123456);
        sBob = address(949330);

        sOwnerFreezable = IOwnerFreezableV1(
            LibOffchainAssetVaultCreator.createVault(
                vm, iFactory, iImplementation, iAuthorizerImplementation, sAlice, "vault", "VLT"
            )
        );
    }
}
