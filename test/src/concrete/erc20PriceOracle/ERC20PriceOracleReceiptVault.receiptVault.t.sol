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
import {IReceiptVaultV1} from "src/interface/IReceiptVaultV1.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";

contract ERC20PriceOracleReceiptVaultreceiptVaultTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test vault asset
    function testVaultAsset(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        assertEq(vault.asset(), address(iAsset));
    }

    /// Test vault totalAssets
    function testTotalAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint256 assets,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        timestamp = bound(timestamp, 0, type(uint32).max);
        assets = bound(assets, 1, type(uint256).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        vm.mockCall(
            address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, address(vault)), abi.encode(assets)
        );

        uint256 resultAssets = vault.totalAssets();

        assertEqUint(assets, resultAssets);
    }

    /// Test convertToAssets
    function testConvertToAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint256 shares,
        uint256 id,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        id = bound(id, 1, type(uint256).max);
        timestamp = bound(timestamp, 0, type(uint32).max);
        shares = bound(shares, 1, type(uint64).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 expectedAssets = shares.fixedPointDiv(id, Math.Rounding.Down);
        uint256 resultAssets = vault.convertToAssets(shares, id);

        assertEqUint(expectedAssets, resultAssets);
    }

    /// Test convertToAssets shows no variations based on caller
    function testConvertToAssetsDifferentCaller(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 timestamp,
        uint256 shares,
        uint256 id,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        id = bound(id, 1, type(uint256).max);
        timestamp = bound(timestamp, 0, type(uint32).max);
        shares = bound(shares, 1, type(uint64).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 resultAssetsAlice = vault.convertToAssets(shares, id);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultAssetsBob = vault.convertToAssets(shares, id);

        assertEqUint(resultAssetsAlice, resultAssetsBob);
    }

    /// Test convertToShares
    function testConvertToShares(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint256 assets,
        uint256 id,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        id = bound(id, 0, type(uint128).max);
        timestamp = bound(timestamp, 0, type(uint32).max);
        assets = bound(assets, 1, type(uint128).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 expectedShares = assets.fixedPointMul(id, Math.Rounding.Down);
        uint256 resultShares = vault.convertToShares(assets, id);

        assertEqUint(expectedShares, resultShares);
    }

    /// Test convertToShares
    function testConvertToSharesDifferentCaller(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 timestamp,
        uint256 assets,
        uint256 id,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Generate unique addresses
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        // Bound the ID to a range that could actually be a price.
        id = bound(id, 0, type(uint128).max);

        timestamp = bound(timestamp, 0, type(uint32).max);

        // Bound the assets to a reasonable range
        assets = bound(assets, 1, type(uint128).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);
        uint256 resultSharesAlice = vault.convertToShares(assets, id);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultSharesBob = vault.convertToShares(assets, id);

        assertEqUint(resultSharesAlice, resultSharesBob);
    }

    /// Test vault sets correct max deposit
    function testMaxDeposit(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 maxDeposit = vault.maxDeposit(alice);

        assertEqUint(maxDeposit, type(uint256).max);
    }

    /// Test vault sets correct max Mint
    function testMaxShares(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 maxMint = vault.maxMint(alice);

        assertEqUint(maxMint, type(uint256).max);
    }

    /// Test vault receiptVaultInformation
    function testReceiptVaultInformation(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound,
        bytes memory information
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        vm.expectEmit(false, false, false, true);
        emit IReceiptVaultV1.ReceiptVaultInformation(alice, information);

        vault.receiptVaultInformation(information);
    }
}
