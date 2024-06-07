// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {
    ZeroAssetsAmount,
    ZeroSharesAmount,
    ZeroReceiver,
    ZeroOwner,
    InvalidId
} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {OffchainAssetReceiptVault} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {LibFixedPointMath, Math} from "@rainprotocol/rain-protocol/contracts/math/LibFixedPointMath.sol";
import {OffchainAssetVaultCreator} from "./OffchainAssetVaultCreator.sol";
import {Receipt} from "../../contracts/vault/receipt/Receipt.sol";

contract WithdrawTest is Test, CreateOffchainAssetReceiptVaultFactory {
    using LibFixedPointMath for uint256;

    event WithdrawWithReceipt(
        address sender,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares,
        uint256 id,
        bytes receiptInformation
    );

    /// Test withdraw function emits WithdrawWithReceipt event
    function testWithdraw(
        uint256 fuzzedKeyAlice,
        uint256 aliceAssets,
        uint256 shareRatio,
        bytes memory data,
        string memory assetName,
        string memory assetSymbol
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        shareRatio = bound(shareRatio, 1, 1e18);
        address alice = vm.addr(fuzzedKeyAlice);
        // Assume that aliceAssets is not 0
        vm.assume(aliceAssets != 0);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVault vault = OffchainAssetVaultCreator.createVault(factory, alice, assetName, assetSymbol);
        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.grantRole(vault.WITHDRAWER(), alice);

        // Call the deposit function
        vault.deposit(aliceAssets, alice, shareRatio, data);

        // Calculate expected shares
        uint256 expectedShares = aliceAssets.fixedPointMul(1e18, Math.Rounding.Up);
        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(true, true, true, true);
        emit WithdrawWithReceipt(alice, alice, alice, aliceAssets, expectedShares, 1, data);

        // Call withdraw function
        vault.withdraw(aliceAssets, alice, alice, 1, data);

        // Stop the prank
        vm.stopPrank();
    }
}
