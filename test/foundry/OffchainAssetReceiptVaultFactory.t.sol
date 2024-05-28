// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

uint256 constant MAX_VALID_PRIVATE_KEY = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;

contract OffChainAssetReceiptVaultFactoryTest is Test, CreateOffchainAssetReceiptVaultFactory {
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault vault;

    ///Test that OffchainAssetReceiptVaultFactory is created
    function testOffchainAssetReceiptVaultFactoryConstuction() external {
        //check address
        assert(address(factory) != address(0));

        //check codeSize
        address factoryAddress = address(factory);
        uint256 size;
        assembly {
            size := extcodesize(factoryAddress)
        }
        assertTrue(size > 0);
    }

    ///Test OffchainAssetReceiptVaultFactory child is created with correct properties
    ///and that OffchainAssetReceiptVaultInitialized event is emitted
    function testCreateChild(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        vm.assume(fuzzedKeyAlice > 0 && fuzzedKeyAlice < MAX_VALID_PRIVATE_KEY);
        address alice = vm.addr(fuzzedKeyAlice);

        // VaultConfig to create child contract
        vaultConfig = VaultConfig(address(0), assetName, assetSymbol);

        // Simulate transaction from alice
        vm.prank(alice);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        vault = factory.createChildTyped(offchainAssetVaultConfig);

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender = address(0);
        address admin = address(0);
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
                break;
            }
        }

        assertEq(msgSender, address(factory));
        assertEq(admin, alice);
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
    }
}
