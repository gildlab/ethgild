// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultFactoryTest is Test, CreateOffchainAssetReceiptVaultFactory {
    /// Test that OffchainAssetReceiptVaultFactory is created
    function testOffchainAssetReceiptVaultFactoryConstuction() external {
        // Check address
        assert(address(factory) != address(0));

        // Check codeSize
        address factoryAddress = address(factory);
        uint256 size;
        assembly {
            size := extcodesize(factoryAddress)
        }
        assertTrue(size > 0);
    }

    /// Test OffchainAssetReceiptVaultFactory child is created with correct properties
    /// and that OffchainAssetReceiptVaultInitialized event is emitted
    function testCreateChild(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // VaultConfig to create child contract
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});

        // Simulate transaction from alice
        vm.prank(alice);
        OffchainAssetVaultConfig memory offchainAssetVaultConfig =
            OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = factory.createChildTyped(offchainAssetVaultConfig);

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender = address(0);
        address admin = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (address sender, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                msgSender = sender;
                admin = config.admin;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }

        // Assert that the event log was found
        assertTrue(eventFound, "OffchainAssetReceiptVaultInitialized event log not found");

        assertEq(msgSender, address(factory));
        assertEq(admin, alice);
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
    }
}
