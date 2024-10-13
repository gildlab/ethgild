// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {VaultConfig} from "contracts/abstract/ReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig,
    ZeroAdmin,
    NonZeroAsset
} from "contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {IReceiptV1} from "contracts/interface/IReceiptV1.sol";

contract OffChainAssetReceiptVaultTest is OffchainAssetReceiptVaultTest {
    /// Test that admin is not address zero
    function testZeroAdmin(string memory assetName, string memory assetSymbol) external {
        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});

        vm.expectRevert(abi.encodeWithSelector(ZeroAdmin.selector));
        iFactory.clone(
            address(iImplementation),
            abi.encode(OffchainAssetVaultConfig({admin: address(0), vaultConfig: vaultConfig}))
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
            address(iImplementation), abi.encode(OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig}))
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
        OffchainAssetVaultConfig memory offchainAssetVaultConfig =
            OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(iFactory.clone(address(iImplementation), abi.encode(offchainAssetVaultConfig)));

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

        assertEq(msgSender, address(iFactory));
        assertEq(admin, alice);
        assert(address(vault) != address(0));
        assertEq(keccak256(bytes(vault.name())), keccak256(bytes(assetName)));
        assertEq(keccak256(bytes(vault.symbol())), keccak256(bytes(assetSymbol)));
    }

    /// Test that vault is the owner of its receipt
    function testVaultIsReceiptOwner(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        VaultConfig memory vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});
        OffchainAssetVaultConfig memory offchainAssetVaultConfig =
            OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        OffchainAssetReceiptVault vault =
            OffchainAssetReceiptVault(iFactory.clone(address(iImplementation), abi.encode(offchainAssetVaultConfig)));

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
                (address sender, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                msgSender = sender;
                break;
            }
        }
        // Create an instance of the Receipt contract
        IReceiptV1 receipt = IReceiptV1(receiptAddress);

        // Check that the receipt address is not zero
        assert(receiptAddress != address(0));
        // Check sender
        assertEq(msgSender, address(iFactory));

        // Interact with the receipt contract
        address owner = receipt.owner();
        assertEq(owner, address(vault));
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
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

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
