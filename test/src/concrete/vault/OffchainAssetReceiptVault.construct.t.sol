// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptVaultConfigV2} from "src/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetReceiptVaultConfigV2,
    OffchainAssetReceiptVaultConfigV2,
    ZeroInitialAdmin,
    NonZeroAsset
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffChainAssetReceiptVaultTest is OffchainAssetReceiptVaultTest {
    /// Test that admin is not address zero
    function testZeroInitialAdmin(string memory shareName, string memory shareSymbol) external {
        ReceiptVaultConfigV2 memory vaultConfig = ReceiptVaultConfigV2({asset: address(0), name: shareName, symbol: shareSymbol});

        vm.expectRevert(abi.encodeWithSelector(ZeroInitialAdmin.selector));
        I_FACTORY.clone(
            address(I_IMPLEMENTATION),
            abi.encode(OffchainAssetReceiptVaultConfigV2({initialAdmin: address(0), receiptVaultConfig: vaultConfig}))
        );
    }

    /// Test that asset is address zero
    function testNonZeroAsset(uint256 aliceSeed, address asset, string memory shareName, string memory shareSymbol)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        vm.assume(asset != address(0));
        ReceiptVaultConfigV2 memory vaultConfig = ReceiptVaultConfigV2({asset: asset, name: shareName, symbol: shareSymbol});

        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        I_FACTORY.clone(
            address(I_IMPLEMENTATION),
            abi.encode(OffchainAssetReceiptVaultConfigV2({initialAdmin: alice, vaultConfig: vaultConfig}))
        );
    }

    /// Test that offchainAssetReceiptVault constructs well
    function testConstructionEvent(uint256 aliceSeed, string memory shareName, string memory shareSymbol) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        address asset = address(0);

        ReceiptVaultConfigV2 memory vaultConfig = ReceiptVaultConfigV2({asset: asset, name: shareName, symbol: shareSymbol});

        // Simulate transaction from alice
        vm.prank(alice);
        OffchainAssetReceiptVaultConfigV2 memory offchainAssetVaultConfig =
            OffchainAssetReceiptVaultConfigV2({initialAdmin: alice, receiptVaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(I_FACTORY.clone(address(I_IMPLEMENTATION), abi.encode(offchainAssetVaultConfig)))
        );

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address msgSender;

        OffchainAssetReceiptVaultConfigV2 memory config;
        bool eventFound = false;

        address authorizeSetMsgSender;
        address authorizeSetTo;
        bool authorizeSetEventFound = false;
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
            } else if (logs[i].topics[0] == keccak256("AuthorizerSet(address,address)")) {
                // Decode the event data
                (authorizeSetMsgSender, authorizeSetTo) = abi.decode(logs[i].data, (address, address));
                authorizeSetEventFound = true; // Set the flag to true since event log was found
            }
        }

        // Assert that the event log was found
        assertTrue(eventFound, "OffchainAssetReceiptVaultInitialized event log not found");

        assertEq(msgSender, address(I_FACTORY));
        assertEq(config.initialAdmin, alice);
        assert(address(vault) != address(0));

        assertEq(config.receiptVaultConfig.vaultConfig.name, shareName);
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(shareName)));

        assertEq(config.receiptVaultConfig.vaultConfig.symbol, shareSymbol);
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(shareSymbol)));

        assertEq(address(config.receiptVaultConfig.vaultConfig.asset), asset);

        assertTrue(address(config.receiptVaultConfig.receipt) != address(0));
        assertEq(address(config.receiptVaultConfig.receipt), address(vault.receipt()));

        /// Check the authorizer set event
        assertTrue(authorizeSetEventFound, "AuthorizerSet event log not found");
        assertEq(authorizeSetMsgSender, address(I_FACTORY));
        assertEq(authorizeSetTo, address(vault));
        assertTrue(address(vault) != address(0));

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
