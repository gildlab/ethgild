// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {MinShareRatio, ZeroAssetsAmount, ZeroReceiver} from "../../../../../contracts/abstract/ReceiptVault.sol";
import {ERC20PriceOracleReceiptVault} from "../../../../../contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {ERC20PriceOracleReceiptVaultTest, Vm} from "test/foundry/abstract/ERC20PriceOracleReceiptVaultTest.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "../../../../../contracts/oracle/price/TwoPriceOracle.sol";
import {TestErc20} from "../../../../../contracts/test/TestErc20.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    event DepositWithReceipt(
        address sender, address owner, uint256 assets, uint256 shares, uint256 id, bytes receiptInformation
    );

    /// Test deposit function
    function testDeposit(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 timestamp,
        uint256 assets,
        uint8 xauDecimals,
        uint8 usdDecimals
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        usdDecimals = uint8(bound(usdDecimals, 6, 18));
        xauDecimals = uint8(bound(xauDecimals, 6, 18));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp);

        ERC20PriceOracleReceiptVault vault;
        TestErc20 asset;
        (vault, asset) = createVault(address(twoPriceOracle), assetName, assetSymbol);

        // Getting ZeroSharesAmount if bounded from 1
        assets = bound(assets, 2, asset.totalSupply());

        uint256 oraclePrice = twoPriceOracle.price();
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vm.prank(alice);
        asset.increaseAllowance(address(vault), asset.totalSupply());

        vault.deposit(assets, alice, oraclePrice, data);

        // Assert that the total assets is equal to deposited assets
        assertEqUint(vault.totalAssets(), assets);
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check alice balance
        assertEqUint(vault.balanceOf(alice), expectedShares);
    }

    /// Test deposit to someone else
    function testDeposit(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        bytes memory data,
        uint256 timestamp,
        uint256 assets,
        uint8 xauDecimals,
        uint8 usdDecimals
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        usdDecimals = uint8(bound(usdDecimals, 6, 18));
        xauDecimals = uint8(bound(xauDecimals, 6, 18));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp);

        ERC20PriceOracleReceiptVault vault;
        {
            TestErc20 asset;
            (vault, asset) = createVault(address(twoPriceOracle), assetName, assetName);

            // Getting ZeroSharesAmount if bounded from 1
            assets = bound(assets, 2, asset.totalSupply());

            vm.prank(alice);
            asset.increaseAllowance(address(vault), asset.totalSupply());
        }
        uint256 oraclePrice = twoPriceOracle.price();
        uint256 expectedShares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.deposit(assets, bob, oraclePrice, data);
        // Assert that the total assets is equal to deposited assets
        assertEqUint(vault.totalAssets(), assets);
        // Assert that the total supply is equal to expectedShares
        assertEqUint(vault.totalSupply(), expectedShares);
        // Check balance
        assertEqUint(vault.balanceOf(bob), expectedShares);
    }

    /// Test deposit function with zero assets
    function testDepositWithZeroAssets(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        usdDecimals = uint8(bound(usdDecimals, 6, 18));
        xauDecimals = uint8(bound(xauDecimals, 6, 18));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp);

        (ERC20PriceOracleReceiptVault vault,) = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.deposit(0, alice, oraclePrice, data);
    }

    /// Test deposit reverts with incorret price
    function testDepositWithIncorrectPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 assets,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        usdDecimals = uint8(bound(usdDecimals, 6, 18));
        xauDecimals = uint8(bound(xauDecimals, 6, 18));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp);

        assets = bound(assets, 1, type(uint256).max);
        (ERC20PriceOracleReceiptVault vault,) = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, oraclePrice + 1, oraclePrice));
        vault.deposit(assets, alice, oraclePrice + 1, data);
    }

    /// Test deposit reverts with zero receiver
    function testDepositWithZeroReceiver(
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint256 assets,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals
    ) external {
        // Use common decimal bounds for price feeds
        usdDecimals = uint8(bound(usdDecimals, 6, 18));
        xauDecimals = uint8(bound(xauDecimals, 6, 18));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp);

        assets = bound(assets, 1, type(uint256).max);
        (ERC20PriceOracleReceiptVault vault,) = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert();
        vault.deposit(assets, address(0), oraclePrice, data);
    }
}
