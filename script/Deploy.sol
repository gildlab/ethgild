// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {OwnableOracle} from "contracts/concrete/oracle/OwnableOracle.sol";
import {
    ERC20PriceOracleReceiptVault,
    ERC20PriceOracleVaultConfig
} from "contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {VaultConfig} from "contracts/abstract/ReceiptVault.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {
    FtsoCurrentPriceUsdOracle,
    FtsoCurrentPriceUsdOracleConfig
} from "contracts/concrete/oracle/FtsoCurrentPriceUsdOracle.sol";
import {
    OffchainAssetReceiptVault,
    ReceiptVaultConstructionConfig
} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";
import {SceptreStakedFlrOracle} from "contracts/concrete/oracle/SceptreStakedFlrOracle.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "contracts/concrete/oracle/TwoPriceOracle.sol";
import {IStakedFlr} from "contracts/interface/sceptre/IStakedFlr.sol";

bytes32 constant DEPLOYMENT_SUITE_IMPLEMENTATIONS = keccak256("implementations");
bytes32 constant DEPLOYMENT_SUITE_OWNABLE_ORACLE_VAULT = keccak256("ownable-oracle-vault");
bytes32 constant DEPLOYMENT_SUITE_STAKED_FLR_PRICE_VAULT = keccak256("sceptre-staked-flare-price-vault");

/// @title Deploy
/// This is intended to be run on every commit by CI to a testnet such as mumbai,
/// then cross chain deployed to whatever mainnet is required, by users.
contract Deploy is Script {
    function deployImplementations(uint256 deploymentKey) internal {
        vm.startBroadcast(deploymentKey);

        new OwnableOracle();
        ReceiptContract receipt = new ReceiptContract();
        ReceiptVaultConstructionConfig memory receiptVaultConstructionConfig = ReceiptVaultConstructionConfig({
            factory: ICloneableFactoryV2(vm.envAddress("CLONE_FACTORY")),
            receiptImplementation: receipt
        });
        // new OffchainAssetReceiptVault(receiptVaultConstructionConfig);
        new ERC20PriceOracleReceiptVault(receiptVaultConstructionConfig);

        vm.stopBroadcast();
    }

    function deployStakedFlrPriceVault(uint256 deploymentKey) internal {
        vm.startBroadcast(deploymentKey);
        address flareFTSOOracle = address(
            new FtsoCurrentPriceUsdOracle(
                FtsoCurrentPriceUsdOracleConfig({
                    symbol: "FLR",
                    // 30 mins.
                    staleAfter: 1800
                })
            )
        );
        address stakedFlr = vm.envAddress("SCEPTRE_STAKED_FLR_ADDRESS");
        address stakedFlrOracle = address(new SceptreStakedFlrOracle(IStakedFlr(stakedFlr)));
        address twoPriceOracle =
            address(new TwoPriceOracle(TwoPriceOracleConfig({base: flareFTSOOracle, quote: stakedFlrOracle})));

        ICloneableFactoryV2(vm.envAddress("CLONE_FACTORY")).clone(
            vm.envAddress("ERC20_PRICE_ORACLE_VAULT_IMPLEMENTATION"),
            abi.encode(
                ERC20PriceOracleVaultConfig({
                    priceOracle: twoPriceOracle,
                    vaultConfig: VaultConfig({
                        asset: stakedFlr,
                        name: vm.envString("RECEIPT_VAULT_NAME"),
                        symbol: vm.envString("RECEIPT_VAULT_SYMBOL")
                    })
                })
            )
        );
        vm.stopBroadcast();
    }

    // function deployOwnableOracleVault(uint256 deploymentKey) internal {
    //     ICloneableFactoryV2 factory =
    //         ICloneableFactoryV2(vm.envAddress("CLONE_FACTORY"));

    //     vm.startBroadcast(deploymentKey);

    //     // Deploy OwnableOracle
    //     OwnableOracle oracle = new OwnableOracle();
    //     oracle.transferOwnership(vm.envAddress("OWNER_ADDRESS"));

    //     factory.clone(
    //         vm.envAddress("ERC20_PRICE_ORACLE_VAULT_IMPLEMENTATION"),
    //         abi.encode(
    //             ERC20PriceOracleVaultConfig({
    //                 priceOracle: address(oracle),
    //                 vaultConfig: VaultConfig({
    //                     asset: vm.envAddress("RECEIPT_VAULT_ASSET"),
    //                     name: vm.envString("RECEIPT_VAULT_NAME"),
    //                     symbol: vm.envString("RECEIPT_VAULT_SYMBOL")
    //                 })
    //             })
    //         )
    //     );

    //     vm.stopBroadcast();
    // }

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
