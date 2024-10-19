// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle} from "src/concrete/oracle/TwoPriceOracle.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test mint function
    function testMintBasic(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            uint256 totalSupply = iAsset.totalSupply();
            assets = bound(assets, 1, totalSupply);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, alice, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(alice), shares);
    }

    /// Test mint to someone else
    function testMintSomeoneElse(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        vm.startPrank(alice);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        {
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            uint256 totalSupply = iAsset.totalSupply();
            assets = bound(assets, 1, totalSupply);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, bob, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(bob), shares);
    }

    /// Test mint function with zero shares
    function testMintWithZeroShares(uint256 fuzzedKeyAlice, string memory assetName, uint256 oraclePrice) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.mint(0, alice, oraclePrice, bytes(""));
    }

    /// Test mint reverts with min price
    function testMintWithMinPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minPrice,
        uint256 oraclePrice
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.assume(minPrice > oraclePrice);
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, minPrice, oraclePrice));
        vault.mint(shares, alice, minPrice, bytes(""));
    }

    /// Test PreviewMint returns correct assets
    function testPreviewMintReturnedAssets(
        string memory assetName,
        string memory assetSymbol,
        uint256 shares,
        uint256 oraclePrice
    ) external {
        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        shares = bound(shares, 1, type(uint64).max);
        vm.assume(shares.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        uint256 assets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Up);

        uint256 resultAssets = vault.previewMint(shares, 0);

        assertEqUint(assets, resultAssets);

        vm.stopPrank();
    }

    fallback() external {}
}
