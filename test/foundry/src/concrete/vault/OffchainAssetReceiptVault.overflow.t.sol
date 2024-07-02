// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {
    OffchainAssetReceiptVault,
    CertificationExpired
} from "../../../../../contracts/concrete/vault/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultTest, Vm} from "test/foundry/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/foundry/lib/LibOffchainAssetVaultCreator.sol";

import "forge-std/console.sol";

contract OffchainAssetReceiptVaultDepositTest is OffchainAssetReceiptVaultTest {
    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test two deposit calls
    function testTwoDeposits(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        uint256 assets,
        uint256 assetsSecond,
        uint256 minShareRatio,
        bytes memory fuzzedReceiptInformation,
        string memory assetName,
        string memory assetSymbol
    ) external {
        minShareRatio = bound(minShareRatio, 0, 1e18);

        // Ensure the fuzzed key is within the valid range for secp256k1
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        vm.assume(alice != bob);

        assets = bound(assets, 1, type(uint256).max);
        vm.assume(assetsSecond != assets);

        assetsSecond = bound(assetsSecond, 1, type(uint256).max);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice to grant roles
        vm.startPrank(alice);

        vault.grantRole(vault.DEPOSITOR(), bob);

        // Prank as Bob for the transaction
        vm.startPrank(bob);

        // Set up the event expectation for DepositWithReceipt
        vm.expectEmit(false, false, false, true);
        emit DepositWithReceipt(bob, bob, assets, assets, 1, fuzzedReceiptInformation);

        // Call the deposit functions
        vault.deposit(assets, bob, minShareRatio, fuzzedReceiptInformation);
        vault.deposit(assetsSecond, bob, minShareRatio, fuzzedReceiptInformation);

        // Stop the prank
        vm.stopPrank();
    }
}
