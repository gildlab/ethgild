// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";

contract OffchainAssetReceiptVaultPreviewMintTest is OffchainAssetReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test PreviewMint returns correct assets
    function testPreviewMintReturnedAssets(
        uint256 aliceKey,
        uint256 bobKey,
        string memory assetName,
        string memory assetSymbol,
        uint256 shares
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey, bobKey);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, bob);
        // Prank as Bob for the transactions

        vm.startPrank(bob);
        uint256 assets = vault.previewMint(shares, 0);

        assertEqUint(shares, assets);

        vm.stopPrank();
    }

    receive() external payable {}

    fallback() external payable {}
}
