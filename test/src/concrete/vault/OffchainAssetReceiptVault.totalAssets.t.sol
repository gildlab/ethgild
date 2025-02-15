// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {OffchainAssetReceiptVault, DEPOSIT, WITHDRAW} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {OffchainAssetReceiptVaultAuthorizorV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizorV1.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract OffchainAssetReceiptVaultTotalAssetsTest is OffchainAssetReceiptVaultTest {
    /// Test vault totalAssets
    function testTotalAssets(uint256 aliceKey, string memory assetName, uint256 assets) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);

        assets = bound(assets, 1, type(uint256).max);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetName);

        vm.startPrank(alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(DEPOSIT, alice);
        OffchainAssetReceiptVaultAuthorizorV1(address(vault.authorizor())).grantRole(WITHDRAW, alice);

        vm.mockCall(address(0), abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)), abi.encode(assets));
        vm.expectCall(address(0), abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)), 0);

        uint256 resultAssets = vault.totalAssets();

        assertEqUint(resultAssets, vault.totalSupply());
        assertEqUint(resultAssets, 0);

        vault.deposit(assets, alice, 0, "");

        resultAssets = vault.totalAssets();

        assertEqUint(resultAssets, vault.totalSupply());
        assertEqUint(resultAssets, assets);

        vault.withdraw(assets, alice, alice, 1, "");

        resultAssets = vault.totalAssets();

        assertEqUint(resultAssets, vault.totalSupply());
        assertEqUint(resultAssets, 0);
    }
}
