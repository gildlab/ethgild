// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {VaultConfig} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfigV2,
    OffchainAssetReceiptVaultConfigV2,
    ZeroInitialAdmin,
    NonZeroAsset
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IReceiptV2} from "src/interface/IReceiptV2.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffChainAssetReceiptVaultTest is OffchainAssetReceiptVaultTest {
    /// Test that admin is not address zero
    function testZeroInitialAdmin(string memory assetName, string memory assetSymbol) external {
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});

        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(OffchainAssetVaultConfigV2({initialAdmin: address(0), vaultConfig: vaultConfig}))
        );
    }

    /// Test that asset is address zero
    function testNonZeroAsset(uint256 aliceKey, address asset, string memory assetName, string memory assetSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);

        vm.assume(asset != address(0));
        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});

        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(OffchainAssetVaultConfigV2({initialAdmin: alice, vaultConfig: vaultConfig}))
        );
    }

    /// Test that offchainAssetReceiptVault constructs well
    function testConstructionEvent(uint256 aliceKey, string memory assetName, string memory assetSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);

        address asset = address(0);

        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});

        // Simulate transaction from alice
        vm.prank(alice);
        OffchainAssetVaultConfigV2 memory offchainAssetVaultConfig =
            OffchainAssetVaultConfigV2({initialAdmin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(iFactory.clone(address(iImplementation), abi.encode(offchainAssetVaultConfig)))
        );

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender;

        OffchainAssetReceiptVaultConfigV2 memory config;
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitializedV2(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (msgSender, config) = abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfigV2));
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }

        // Assert that the event log was found
        assertTrue(eventFound, "OffchainAssetReceiptVaultInitialized event log not found");

        assertEq(msgSender, address(iFactory));
        assertEq(config.initialAdmin, alice);
        assert(address(vault) != address(0));

        assertEq(config.receiptVaultConfig.vaultConfig.name, assetName);
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));

        assertEq(config.receiptVaultConfig.vaultConfig.symbol, assetSymbol);
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));

        assertEq(address(config.receiptVaultConfig.vaultConfig.asset), asset);

        assertTrue(address(config.receiptVaultConfig.receipt) != address(0));
        assertEq(address(config.receiptVaultConfig.receipt), address(vault.receipt()));

        // Check the receipt manager is the vault.
        assertEq(address(vault), vault.receipt().manager());
    }

    /// Test creating several different vaults
    function testCreatingSeveralVaults(
        uint256 aliceKey,
        uint256 bobKey,
        string memory assetName,
        string memory assetSymbol,
        string memory assetNameTwo,
        string memory assetSymbolTwo
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, bobKey);

        // Simulate transaction from alice
        vm.prank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
        assertEq(address(vault.receipt().manager()), address(vault));
        assertEq(vault.owner(), alice);

        // Simulate transaction from alice
        vm.prank(bob);

        OffchainAssetReceiptVault vaultTwo = createVault(bob, assetNameTwo, assetSymbolTwo);

        assert(address(vaultTwo) != address(0));
        assertEq(keccak256(bytes(vaultTwo.name())), keccak256(bytes(assetNameTwo)));
        assertEq(keccak256(bytes(vaultTwo.symbol())), keccak256(bytes(assetSymbolTwo)));
        assertEq(address(vaultTwo.receipt().manager()), address(vaultTwo));
        assertEq(vaultTwo.owner(), bob);
    }
}
