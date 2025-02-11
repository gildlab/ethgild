// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

contract ERC20PriceOracleReceiptVaultPreviewDepositTest is ERC20PriceOracleReceiptVaultTest {
    /// Test PreviewDeposit returns correct shares
    function testPreviewDepositReturnedShares(
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        uint256 shares = vault.previewDeposit(assets, 0);

        assertEqUint(shares, expectedShares);

        vm.stopPrank();
    }
}