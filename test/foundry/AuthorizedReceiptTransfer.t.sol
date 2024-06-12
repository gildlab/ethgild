// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    CertificationExpired
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";

contract AuthorizedReceiptTransfer is Test, CreateOffchainAssetReceiptVaultFactory {
    ///Test AuthorizeReceiptTransfer reverts if system not certified
    function testAuthorizeReceiptTransferRevert(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 warpTimestamp,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        // Bound warpTimestamp from 1 to avoid potential issues with timestamp 0.
        warpTimestamp = bound(warpTimestamp, 1, type(uint32).max);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Warp the block timestamp to a non-zero value
        vm.warp(warpTimestamp);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Assuming that the certification is expired
        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, bob, alice, 0, warpTimestamp));

        // Attempt to authorize receipt transfer, should revert
        vault.authorizeReceiptTransfer(bob, alice);

        vm.stopPrank();
    }

    ///Test AuthorizeReceiptTransfer does not reverts without certification if FROM has a handler role
    function testAuthorizeReceiptTransferForHandlerFrom(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.HANDLER(), bob);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }

    ///Test AuthorizeReceiptTransfer does not revert without certification if To has a handler role
    function testAuthorizeReceiptTransferForHandlerTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);

        vault.grantRole(vault.HANDLER(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }

    ///Test AuthorizeReceiptTransfer does not revert without certification if To has a confiscator role
    function testAuthorizeReceiptTransferForConfiscatorTo(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);

        vm.assume(alice != bob);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Prank as Alice to set role
        vm.startPrank(alice);
        vault.grantRole(vault.CONFISCATOR(), alice);

        vm.startPrank(bob);

        vm.expectCall(address(vault), abi.encodeCall(vault.authorizeReceiptTransfer, (bob, alice)));
        vault.authorizeReceiptTransfer(bob, alice);
    }
}
