// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm, stdError} from "forge-std/Test.sol";
import {OffchainAssetReceiptVault} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract Overflows is Test, CreateOffchainAssetReceiptVaultFactory {
    /// Check positive overflow for mint
    function testMintOverflow(
        uint256 fuzzedKeyAlice,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);

        vm.expectRevert(stdError.arithmeticError);
        vault.mint(UINT256_MAX + 1, alice, 1e18, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Check positive overflow for mint to someone else
    function testMintToSomeoneElseOverflow(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);

        vm.expectRevert(stdError.arithmeticError);
        vault.mint(UINT256_MAX + 1, bob, 1e18, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Check positive overflow for deposit
    function testDepositOverflow(
        uint256 fuzzedKeyAlice,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);

        vm.expectRevert(stdError.arithmeticError);
        vault.mint(UINT256_MAX + 1, alice, 1e18, fuzzedReceiptInformation);

        vm.stopPrank();
    }

    /// Check positive overflow for deposit to someone else
    function testDepositToSomeoneElseOverflow(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), alice);

        vm.expectRevert(stdError.arithmeticError);
        vault.deposit(UINT256_MAX + 1, bob, 1e18, fuzzedReceiptInformation);

        vm.stopPrank();
    }
}
