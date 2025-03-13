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
import {IReceiptV3} from "src/interface/IReceiptV3.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffChainAssetReceiptVaultTest is OffchainAssetReceiptVaultTest {
    /// Test that admin is not address zero
    function testZeroInitialAdmin(string memory shareName, string memory shareSymbol) external {
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: shareName, symbol: shareSymbol});

        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(OffchainAssetVaultConfigV2({initialAdmin: address(0), vaultConfig: vaultConfig}))
        );
    }

    /// Test that asset is address zero
    function testNonZeroAsset(uint256 aliceSeed, address asset, string memory shareName, string memory shareSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        vm.assume(asset != address(0));
        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: shareName, symbol: shareSymbol});

        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(OffchainAssetVaultConfigV2({initialAdmin: alice, vaultConfig: vaultConfig}))
        );
    }

    /// Test that offchainAssetReceiptVault constructs well
    function testConstructionEvent(uint256 aliceSeed, string memory shareName, string memory shareSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        address asset = address(0);

        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: shareName, symbol: shareSymbol});

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

        assertEq(config.receiptVaultConfig.vaultConfig.name, shareName);
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));

        assertEq(config.receiptVaultConfig.vaultConfig.symbol, shareSymbol);
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));

        assertEq(address(config.receiptVaultConfig.vaultConfig.asset), asset);

        assertTrue(address(config.receiptVaultConfig.receipt) != address(0));
        assertEq(address(config.receiptVaultConfig.receipt), address(vault.receipt()));

        // Check the receipt manager is the vault.
        assertEq(address(vault), vault.receipt().manager());
    }

    /// Test creating several different vaults
    function testCreatingSeveralVaults(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol,
        string memory shareNameTwo,
        string memory shareSymbolTwo
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Simulate transaction from alice
        vm.prank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));
        assertEq(address(vault.receipt().manager()), address(vault));
        assertEq(vault.owner(), alice);

        // Simulate transaction from alice
        vm.prank(bob);

        OffchainAssetReceiptVault vaultTwo = createVault(bob, shareNameTwo, shareSymbolTwo);

        assert(address(vaultTwo) != address(0));
        assertEq(keccak256(bytes(vaultTwo.name())), keccak256(bytes(shareNameTwo)));
        assertEq(keccak256(bytes(vaultTwo.symbol())), keccak256(bytes(shareSymbolTwo)));
        assertEq(address(vaultTwo.receipt().manager()), address(vaultTwo));
        assertEq(vaultTwo.owner(), bob);
    }
}
