// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "src/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracleV2} from "src/concrete/oracle/TwoPriceOracleV2.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {SFLR_CONTRACT} from "rain.flare/lib/sflr/LibSceptreStakedFlare.sol";
import {LibERC20PriceOracleReceiptVaultFork} from "../../../lib/LibERC20PriceOracleReceiptVaultFork.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";

contract ERC20PriceOracleReceiptVaultMintTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test mint function
    function testMintBasic(uint256 fuzzedKeyAlice, string memory assetName, uint256 assets, uint256 oraclePrice)
        external
    {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, fuzzedKeyAlice);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        vm.startPrank(alice);

        // Start recording logs to get receipt from ERC20PriceOracleReceiptVaultInitialized event
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        ReceiptContract receipt = getReceipt();

        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, alice, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(alice), shares);

        // Check alice's receipt balance
        assertEqUint(receipt.balanceOf(alice, oraclePrice), shares);
    }

    /// Test multiple mints under different oracle prices
    function testMultipleMints(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 assets,
        uint256 oraclePrice1,
        uint256 oraclePrice2
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, fuzzedKeyAlice);

        oraclePrice1 = bound(oraclePrice1, 0.01e18, 100e18);
        oraclePrice2 = bound(oraclePrice2, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice1);

        vm.startPrank(alice);

        // Start recording logs to get receipt from ERC20PriceOracleReceiptVaultInitialized event
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(iVaultOracle, assetName, assetName);

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice1, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        ReceiptContract receipt = getReceipt();

        uint256 shares1 = assets.fixedPointMul(oraclePrice1, Math.Rounding.Down);

        vault.mint(shares1, alice, oraclePrice1, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(alice), shares1);

        // Check alice's receipt balance
        assertEqUint(receipt.balanceOf(alice, oraclePrice1), shares1);

        // Mint with different oracle price
        setVaultOraclePrice(oraclePrice2);

        vm.startPrank(alice);

        // Ensure Alice has enough balance and allowance
        vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice2, Math.Rounding.Down) > 0);

        vm.mockCall(
            address(iAsset),
            abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
            abi.encode(true)
        );

        uint256 shares2 = assets.fixedPointMul(oraclePrice2, Math.Rounding.Down);

        vault.mint(shares2, alice, oraclePrice2, bytes(""));
        // Check balance
        assertEqUint(vault.balanceOf(alice), shares1 + shares2);

        // // Check alice's receipt balance
        if (oraclePrice1 == oraclePrice2) {
            assertEqUint(receipt.balanceOf(alice, oraclePrice1), shares1 + shares2);
        } else {
            assertEqUint(receipt.balanceOf(alice, oraclePrice1), shares1);
            assertEqUint(receipt.balanceOf(alice, oraclePrice2), shares2);
        }
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

        // Start recording logs to get receipt from ERC20PriceOracleReceiptVaultInitialized event
        vm.recordLogs();
        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetName);

        {
            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            assets = bound(assets, 1, type(uint128).max);
            vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        ReceiptContract receipt = getReceipt();

        uint256 aliceReceiptBalance = receipt.balanceOf(alice, oraclePrice);
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, bob, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(bob), shares);

        // Check bob's receipt balance
        assertEqUint(receipt.balanceOf(bob, oraclePrice), shares);

        // Check alice's receipt balance does not change
        assertEqUint(receipt.balanceOf(alice, oraclePrice), aliceReceiptBalance);
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

    /// Test mint reverts with min share ratio
    function testMintWithMinShareRatio(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 minShareRatio,
        uint256 oraclePrice
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddress(vm, SECP256K1_ORDER, fuzzedKeyAlice);

        oraclePrice = bound(oraclePrice, 0.01e18, 100e18);
        setVaultOraclePrice(oraclePrice);

        assets = bound(assets, 1, type(uint128).max);
        vm.assume(assets.fixedPointMul(oraclePrice, Math.Rounding.Down) > 0);

        ERC20PriceOracleReceiptVault vault = createVault(iVaultOracle, assetName, assetSymbol);

        vm.assume(minShareRatio > oraclePrice);
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, minShareRatio, oraclePrice));
        vault.mint(shares, alice, minShareRatio, bytes(""));
    }

    fallback() external {}
}
