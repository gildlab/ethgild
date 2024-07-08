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

contract ERC20PriceOracleReceiptVaultDepositTest is ERC20PriceOracleReceiptVaultTest {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Test mint function
    function testMint(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        uint256 timestamp,
        uint256 assets,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);
        ERC20PriceOracleReceiptVault vault;
        {
            vault = createVault(address(twoPriceOracle), assetName, assetName);

            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            uint256 totalSupply = iAsset.totalSupply();
            assets = bound(assets, 2, totalSupply);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 oraclePrice = twoPriceOracle.price();
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
        uint256 timestamp,
        uint256 assets,
        uint8 usdDecimals,
        uint80 answeredInRound
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256
        address alice = vm.addr((fuzzedKeyAlice % (SECP256K1_ORDER - 1)) + 1);
        address bob = vm.addr((fuzzedKeyBob % (SECP256K1_ORDER - 1)) + 1);
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);
        vm.startPrank(alice);
        // ERC20PriceOracleReceiptVault vault;
        ERC20PriceOracleReceiptVault vault;

        {
            vault = createVault(address(twoPriceOracle), assetName, assetName);

            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(1e18));

            // Ensure Alice has enough balance and allowance
            vm.mockCall(address(iAsset), abi.encodeWithSelector(IERC20.balanceOf.selector, alice), abi.encode(assets));

            uint256 totalSupply = iAsset.totalSupply();
            assets = bound(assets, 2, totalSupply);

            vm.mockCall(
                address(iAsset),
                abi.encodeWithSelector(IERC20.transferFrom.selector, alice, address(vault), assets),
                abi.encode(true)
            );
        }
        uint256 oraclePrice = twoPriceOracle.price();
        uint256 shares = assets.fixedPointMul(oraclePrice, Math.Rounding.Down);

        vault.mint(shares, bob, oraclePrice, bytes(""));

        // Check balance
        assertEqUint(vault.balanceOf(bob), shares);
    }

    /// Test mint function with zero shares
    function testMintWithZeroShares(
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

        uint256 oraclePrice = twoPriceOracle.price();

        vm.expectRevert(abi.encodeWithSelector(ZeroAssetsAmount.selector));
        vault.mint(0, alice, oraclePrice, bytes(""));
    }

    /// Test mint reverts with min price
    function testMintWithMinPrice(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 assets,
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint80 answeredInRound,
        uint256 minPrice
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
        assets = bound(assets, 1, type(uint256).max);
        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();
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
        uint256 timestamp,
        uint8 xauDecimals,
        uint8 usdDecimals,
        uint8 answeredInRound
    ) external {
        // Use common decimal bounds for price feeds
        // Use 0-20 so we at least have some coverage higher than 18
        usdDecimals = uint8(bound(usdDecimals, 0, 20));
        xauDecimals = uint8(bound(xauDecimals, 0, 20));
        timestamp = bound(timestamp, 0, type(uint32).max);

        vm.warp(timestamp);
        TwoPriceOracle twoPriceOracle = createTwoPriceOracle(usdDecimals, usdDecimals, timestamp, answeredInRound);

        shares = bound(shares, 1, type(uint64).max);
        ERC20PriceOracleReceiptVault vault = createVault(address(twoPriceOracle), assetName, assetSymbol);

        uint256 oraclePrice = twoPriceOracle.price();
        uint256 assets = shares.fixedPointDiv(oraclePrice, Math.Rounding.Up);

        uint256 resultAssets = vault.previewMint(shares);

        assertEqUint(assets, resultAssets);

        vm.stopPrank();
    }
}
