// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ERC20PriceOracleReceiptVaultTest} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultAssetTest is ERC20PriceOracleReceiptVaultTest {
    /// Test vault asset
    function testVaultAsset(uint256 aliceKey, string memory assetName) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, aliceKey);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        assertEq(vault.asset(), address(iAsset));
    }
}
