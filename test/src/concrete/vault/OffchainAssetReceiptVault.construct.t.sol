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
            abi.encode(
                OffchainAssetVaultConfigV2({initialAdmin: address(0), authorizor: iAuthorizor, vaultConfig: vaultConfig})
            )
        );
    }

    /// Test that asset is address zero
    function testNonZeroAsset(uint256 fuzzedKeyAlice, address asset, string memory assetName, string memory assetSymbol)
        external
    {
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(asset != address(0));
        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});

        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(
                OffchainAssetVaultConfigV2({initialAdmin: alice, authorizor: iAuthorizor, vaultConfig: vaultConfig})
            )
        );
    }

    /// Test that offchainAssetReceiptVault constructs well
    function testConstruction(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        address asset = address(0);

        VaultConfig memory vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});

        // Simulate transaction from alice
        vm.prank(alice);
        OffchainAssetVaultConfigV2 memory offchainAssetVaultConfig =
            OffchainAssetVaultConfigV2({initialAdmin: alice, authorizor: iAuthorizor, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(iFactory.clone(address(iImplementation), abi.encode(offchainAssetVaultConfig)))
        );

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
                (address sender, OffchainAssetReceiptVaultConfigV2 memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfigV2));
                msgSender = sender;
                admin = config.initialAdmin;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }

        // Assert that the event log was found
        assertTrue(eventFound, "OffchainAssetReceiptVaultInitialized event log not found");

        assertEq(msgSender, address(iFactory));
        assertEq(admin, alice);
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
    }

    /// Test that vault is the manager of its receipt
    function testVaultIsReceiptManager(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});
        OffchainAssetVaultConfigV2 memory offchainAssetVaultConfig =
            OffchainAssetVaultConfigV2({initialAdmin: alice, authorizor: iAuthorizor, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(
            payable(iFactory.clone(address(iImplementation), abi.encode(offchainAssetVaultConfig)))
        );

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        address msgSender = address(0);
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (address sender, OffchainAssetReceiptVaultConfigV2 memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfigV2));
                receiptAddress = config.receiptVaultConfig.receipt;
                msgSender = sender;
                break;
            }
        }
        // Create an instance of the Receipt contract
        IReceiptV2 receipt = IReceiptV2(receiptAddress);

        // Check that the receipt address is not zero
        assert(receiptAddress != address(0));
        // Check sender
        assertEq(msgSender, address(iFactory));

        // Interact with the receipt contract
        address manager = receipt.manager();
        assertEq(manager, address(vault));
    }

    /// Test creating several different vaults
    function testCreatingSeveralVaults(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        string memory assetNameTwo,
        string memory assetSymbolTwo
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Simulate transaction from alice
        vm.prank(alice);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));

        // Simulate transaction from alice
        vm.prank(bob);

        OffchainAssetReceiptVault vaultTwo = createVault(bob, assetNameTwo, assetSymbolTwo);

        assert(address(vaultTwo) != address(0));
        assertEq(keccak256(bytes(vaultTwo.name())), keccak256(bytes(assetNameTwo)));
        assertEq(keccak256(bytes(vaultTwo.symbol())), keccak256(bytes(assetSymbolTwo)));
    }
}
