// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {VaultConfig} from "src/abstract/ReceiptVault.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfigV2
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {SceptreStakedFlrOracle} from "src/concrete/oracle/SceptreStakedFlrOracle.sol";
import {TwoPriceOracleV2, TwoPriceOracleConfigV2} from "src/concrete/oracle/TwoPriceOracleV2.sol";
import {FtsoV2LTSFeedOracle, FtsoV2LTSFeedOracleConfig} from "src/concrete/oracle/FtsoV2LTSFeedOracle.sol";
import {FLR_USD_FEED_ID} from "rain.flare/lib/lts/LibFtsoV2LTS.sol";
import {IPriceOracleV2} from "src/interface/IPriceOracleV2.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {OffchainAssetReceiptVaultPaymentMintAuthorizerV1} from
    "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";

bytes32 constant DEPLOYMENT_SUITE_IMPLEMENTATIONS = keccak256("implementations");
bytes32 constant DEPLOYMENT_SUITE_OWNABLE_ORACLE_VAULT = keccak256("ownable-oracle-vault");
bytes32 constant DEPLOYMENT_SUITE_STAKED_FLR_PRICE_VAULT = keccak256("sceptre-staked-flare-price-vault");

/// @title Deploy
/// This is intended to be run on every commit by CI to a testnet such as mumbai,
/// then cross chain deployed to whatever mainnet is required, by users.
contract Deploy is Script {
    function deployImplementations(uint256 deploymentKey) internal {
        vm.startBroadcast(deploymentKey);

        ReceiptContract receipt = new ReceiptContract();
        ReceiptVaultConstructionConfigV2 memory receiptVaultConstructionConfig = ReceiptVaultConstructionConfigV2({
            factory: ICloneableFactoryV2(vm.envAddress("CLONE_FACTORY")),
            receiptImplementation: receipt
        });
        new OffchainAssetReceiptVault(receiptVaultConstructionConfig);
        new ERC20PriceOracleReceiptVault(receiptVaultConstructionConfig);
        new OffchainAssetReceiptVaultAuthorizerV1();
        new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();

        vm.stopBroadcast();
    }

    function deployStakedFlrPriceVault(uint256 deploymentKey) internal {
        vm.startBroadcast(deploymentKey);
        //forge-lint: disable-next-line(mixed-case-variable)
        IPriceOracleV2 ftsoV2LTSFeedOracle = IPriceOracleV2(
            new FtsoV2LTSFeedOracle(
                FtsoV2LTSFeedOracleConfig({
                    feedId: FLR_USD_FEED_ID,
                    // 30 mins.
                    staleAfter: 1800
                })
            )
        );
        IPriceOracleV2 stakedFlrOracle = new SceptreStakedFlrOracle();
        IPriceOracleV2 twoPriceOracle = IPriceOracleV2(
            new TwoPriceOracleV2(TwoPriceOracleConfigV2({base: ftsoV2LTSFeedOracle, quote: stakedFlrOracle}))
        );

        ICloneableFactoryV2(vm.envAddress("CLONE_FACTORY")).clone(
            vm.envAddress("ERC20_PRICE_ORACLE_VAULT_IMPLEMENTATION"),
            abi.encode(
                ERC20PriceOracleVaultConfig({
                    priceOracle: twoPriceOracle,
                    vaultConfig: VaultConfig({
                        asset: address(SFLR_CONTRACT),
                        name: vm.envString("RECEIPT_VAULT_NAME"),
                        symbol: vm.envString("RECEIPT_VAULT_SYMBOL")
                    })
                })
            )
        );
        vm.stopBroadcast();
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        bytes32 suite = keccak256(bytes(vm.envString("DEPLOYMENT_SUITE")));

        if (suite == DEPLOYMENT_SUITE_IMPLEMENTATIONS) {
            deployImplementations(deployerPrivateKey);
        } else if (suite == DEPLOYMENT_SUITE_STAKED_FLR_PRICE_VAULT) {
            deployStakedFlrPriceVault(deployerPrivateKey);
        } else {
            revert("Unknown deployment suite");
        }
    }
}
