// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultTotalAssetsTest is ERC20PriceOracleReceiptVaultTest {
    /// Test vault totalAssets
    function testTotalAssets(uint256 aliceKey, string memory assetName, uint256 assets) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, aliceKey);

        assets = bound(assets, 1, type(uint256).max);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        vm.mockCall(
            address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)), abi.encode(assets)
        );
        vm.expectCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)));

        uint256 resultAssets = vault.totalAssets();

        assertEqUint(assets, resultAssets);
    }
}
