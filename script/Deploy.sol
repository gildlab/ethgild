// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Script} from "forge-std/Script.sol";
import {OwnableOracle} from "contracts/concrete/OwnableOracle.sol";
import {ERC20PriceOracleReceiptVault} from "contracts/vault/priceOracle/ERC20PriceOracleReceiptVault.sol";
import {
    ERC20PriceOracleReceiptVaultFactory,
    ReceiptVaultFactoryConfig
} from "contracts/vault/priceOracle/ERC20PriceOracleReceiptVaultFactory.sol";
import {VaultConfig} from "contracts/vault/receipt/ReceiptVault.sol";
import {ERC20PriceOracleVaultConfig} from "contracts/vault/priceOracle/ERC20PriceOracleReceiptVault.sol";
import {ReceiptFactory} from "contracts/vault/receipt/ReceiptFactory.sol";

bytes32 constant DEPLOYMENT_SUITE_ORACLE_VAULT_FACTORY = keccak256("oracle-vault-factory");
bytes32 constant DEPLOYMENT_SUITE_OWNABLE_ORACLE_VAULT = keccak256("ownable-oracle-vault");

/// @title Deploy
/// This is intended to be run on every commit by CI to a testnet such as mumbai,
/// then cross chain deployed to whatever mainnet is required, by users.
contract Deploy is Script {
    function deployOwnableOracleVault(uint256 deploymentKey) internal {
        ERC20PriceOracleReceiptVaultFactory factory =
            ERC20PriceOracleReceiptVaultFactory(vm.envAddress("ERC20_PRICE_ORACLE_RECEIPT_VAULT_FACTORY"));

        vm.startBroadcast(deploymentKey);

        // Deploy OwnableOracle
        OwnableOracle oracle = new OwnableOracle();
        oracle.transferOwnership(vm.envAddress("OWNER_ADDRESS"));

        factory.createChild(
            abi.encode(
                ERC20PriceOracleVaultConfig({
                    priceOracle: address(oracle),
                    vaultConfig: VaultConfig({
                        asset: vm.envAddress("RECEIPT_VAULT_ASSET"),
                        name: vm.envString("RECEIPT_VAULT_NAME"),
                        symbol: vm.envString("RECEIPT_VAULT_SYMBOL")
                    })
                })
            )
        );

        vm.stopBroadcast();
    }

    function deployOracleVaultFactory(uint256 deploymentKey) internal {
        vm.startBroadcast(deploymentKey);

        ERC20PriceOracleReceiptVault implementation = new ERC20PriceOracleReceiptVault();
        ReceiptFactory receiptFactory = new ReceiptFactory();

        // Deploy ERC20PriceOracleReceiptVaultFactory
        ERC20PriceOracleReceiptVaultFactory factory = new ERC20PriceOracleReceiptVaultFactory(
            ReceiptVaultFactoryConfig({implementation: address(implementation), receiptFactory: address(receiptFactory)})
        );
        (factory);

        vm.stopBroadcast();
    }

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYMENT_KEY");
        bytes32 suite = keccak256(bytes(vm.envString("DEPLOYMENT_SUITE")));

        if (suite == DEPLOYMENT_SUITE_ORACLE_VAULT_FACTORY) {
            deployOracleVaultFactory(deployerPrivateKey);
        } else if (suite == DEPLOYMENT_SUITE_OWNABLE_ORACLE_VAULT) {
            deployOwnableOracleVault(deployerPrivateKey);
        } else {
            revert("Unknown deployment suite");
        }
    }
}
