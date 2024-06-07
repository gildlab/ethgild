// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    UnauthorizedSenderTier
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {ReadWriteTier} from "../../contracts/test/ReadWriteTier.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";
import {ITierV2} from "@rainprotocol/rain-protocol/contracts/tier/ITierV2.sol";

contract TiersTest is Test, CreateOffchainAssetReceiptVaultFactory {
    event SetERC20Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);
    event SetERC1155Tier(address sender, address tier, uint256 minimumTier, uint256[] context, bytes data);

    /// Test setERC20Tier event
    function testSetERC20Tier(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory fuzzedData,
        uint8 fuzzedMinTier,
        uint256[] memory fuzzedContext,
        address tier
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        fuzzedMinTier = uint8(bound(fuzzedMinTier, uint256(1), uint256(8)));

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Create the vault
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Grant the necessary role
        vault.grantRole(vault.ERC20TIERER(), alice);

        // Emit the expected event
        vm.expectEmit(true, true, true, true);
        emit SetERC20Tier(alice, address(tier), fuzzedMinTier, fuzzedContext, fuzzedData);

        // Call the function that should emit the event
        vault.setERC20Tier(address(tier), fuzzedMinTier, fuzzedContext, fuzzedData);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test setERC1155Tier event
    function testSetERC1155Tier(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory fuzzedData,
        uint8 fuzzedMinTier,
        uint256[] memory fuzzedContext,
        address tier
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        fuzzedMinTier = uint8(bound(fuzzedMinTier, uint256(1), uint256(8)));

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Create the vault
        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        // Grant the necessary role
        vault.grantRole(vault.ERC1155TIERER(), alice);

        // Emit the expected event
        vm.expectEmit(true, true, true, true);
        emit SetERC1155Tier(alice, tier, fuzzedMinTier, fuzzedContext, fuzzedData);

        // Call the function that should emit the event
        vault.setERC1155Tier(tier, fuzzedMinTier, fuzzedContext, fuzzedData);

        // Stop the prank
        vm.stopPrank();
    }

    /// Test authorizeReceiptTransfer reverts if unauthorizedSenderTier
    function testTransferOnUnauthorizedSenderTier(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        bytes memory fuzzedData,
        uint8 fuzzedMinTier,
        uint256[] memory fuzzedContext,
        uint256 certifyUntil,
        uint256 referenceBlockNumber,
        uint256 fuzzedBlockNumber
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        address alice = vm.addr(fuzzedKeyAlice);

        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        address bob = vm.addr(fuzzedKeyBob);

        referenceBlockNumber = bound(fuzzedBlockNumber, 1, block.number);
        fuzzedBlockNumber = bound(fuzzedBlockNumber, 1, 1e6);
        certifyUntil = bound(certifyUntil, 1, fuzzedBlockNumber);

        vm.assume(alice != bob);

        fuzzedMinTier = uint8(bound(fuzzedMinTier, uint256(1), uint256(8)));

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);

        vault.grantRole(vault.CERTIFIER(), alice);

        // Call the certify function
        vault.certify(certifyUntil, referenceBlockNumber, false, fuzzedData);

        vault.grantRole(vault.ERC1155TIERER(), alice);

        // New TierV2TestContract contract
        ReadWriteTier TierV2TestContract = new ReadWriteTier();
        uint256 fromReportTime_ = TierV2TestContract.reportTimeForTier(alice, fuzzedMinTier, fuzzedContext);

        vault.setERC1155Tier(address(TierV2TestContract), fuzzedMinTier, fuzzedContext, fuzzedData);

        // Expect the revert with the exact revert reason
        // Revert reason must match the UnauthorizedSenderTier with correct encoding
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedSenderTier.selector, alice, fromReportTime_));

        vault.authorizeReceiptTransfer(alice, bob);

        vm.stopPrank();
    }
}
