// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "../../../../../contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/foundry/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle} from "../../../../../contracts/oracle/price/TwoPriceOracle.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

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

    /// Test vault sets the minShareRatio
    function testSetMinShareRatio(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound,
        uint256 minShareRatio
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

        vault.setMinShareRatio(minShareRatio);

        uint256 resultMinShareRatio = vault.sMinShareRatios(alice);

        assertEqUint(minShareRatio, resultMinShareRatio);
    }

    /// Test vault sets the withdraw Id
    function testSetWithdrawId(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound,
        uint256 withdrawId
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

        vault.setWithdrawId(withdrawId);

        uint256 resultwithdrawId = vault.sWithdrawIds(alice);

        assertEqUint(withdrawId, resultwithdrawId);
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
        shares = bound(shares, 1, type(uint64).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 oraclePrice = twoPriceOracle.price();
        uint256 expectedAssets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Down);
        uint256 resultAssets = vault.convertToAssets(shares);

        assertEqUint(expectedAssets, resultAssets);
    }

    /// Test convertToAssets shows no variations based on caller
    function testConvertToAssetsDifferentCaller(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 timestamp,
        uint256 shares,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));

        timestamp = bound(timestamp, 0, type(uint32).max);
        shares = bound(shares, 1, type(uint64).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);

        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetName);

        uint256 resultAssetsAlice = vault.convertToAssets(shares);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultAssetsBob = vault.convertToAssets(shares);

        assertEqUint(resultAssetsAlice, resultAssetsBob);
    }

    /// Test convertToShares
    function testConvertToShares(
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

        uint256 oraclePrice = twoPriceOracle.price();

        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);
        uint256 resultShares = vault.convertToShares(assets);

        assertEqUint(expectedShares, resultShares);
    }

    /// Test convertToShares
    function testConvertToSharesDifferentCaller(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        uint256 timestamp,
        uint256 assets,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
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
        uint256 resultSharesAlice = vault.convertToShares(assets);
        vm.stopPrank();

        vm.startPrank(bob);

        uint256 resultSharesBob = vault.convertToShares(assets);

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
}
