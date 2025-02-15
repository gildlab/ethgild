// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT, WITHDRAW} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultPreviewRedeemTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test PreviewRedeem returns correct shares
    function testPreviewRedeem(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 shares,
        string memory assetName,
        string memory assetSymbol,
        uint256 id
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Assume that shares is not 0
        shares = bound(shares, 1, type(uint64).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);
        // Prank as Alice to grant role
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(WITHDRAW, bob);

        // Prank as Bob for transaction
        vm.startPrank(bob);

        uint256 expectedAssets = shares;

        // Get assets
        uint256 assets = vault.previewRedeem(shares, id);

        assertEq(assets, expectedAssets);
        // Stop the prank
        vm.stopPrank();
    }

    /// Test PreviewRedeem still previews without WITHDRAWER role
    function testPreviewRedeemNoWithdrawer(
        uint256 aliceSeed,
        uint256 shares,
        string memory assetName,
        string memory assetSymbol,
        uint256 id
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        // Assume that shares is not 0
        shares = bound(shares, 1, type(uint256).max);
        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Call previewRedeem function
        uint256 assets = vault.previewRedeem(shares, id);

        assertEq(assets, shares);

        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
