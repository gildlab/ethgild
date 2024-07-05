// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConstructionConfig
} from "contracts/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibERC20PriceOracleReceiptVaultCreator} from "../lib/LibERC20PriceOracleReceiptVaultCreator.sol";
import {Receipt as ReceiptContract} from "contracts/concrete/receipt/Receipt.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "contracts/oracle/price/TwoPriceOracle.sol";
import {
    ChainlinkFeedPriceOracle,
    ChainlinkFeedPriceOracleConfig
} from "contracts/oracle/price/chainlink/ChainlinkFeedPriceOracle.sol";
import {MockChainlinkDataFeed, RoundData} from "contracts/test/MockChainlinkDataFeed.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable iReceiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: iReceiptImplementation})
        );
    }

    function createVault(address priceOracle, string memory name, string memory symbol, address erc20Address)
        internal
        returns (ERC20PriceOracleReceiptVault, IERC20)
    {
        IERC20 asset = IERC20(erc20Address);
        ERC20PriceOracleReceiptVault vault = LibERC20PriceOracleReceiptVaultCreator.createVault(
            iFactory, iImplementation, priceOracle, address(asset), name, symbol
        );
        return (vault, asset);
    }

    function createTwoPriceOracle(uint8 usdDecimals, uint8 xauDecimals, uint256 timestamp)
        internal
        returns (TwoPriceOracle twoPriceOracle)
    {
        int256 basePrice = 1e8; // Example price for base
        int256 quotePrice = 1.8e8; // Example price for quote

        // Deploy base price oracle
        MockChainlinkDataFeed basePriceOracle = new MockChainlinkDataFeed();
        basePriceOracle.setDecimals(usdDecimals);
        basePriceOracle.setRoundData(
            1, RoundData({answer: basePrice, startedAt: timestamp, updatedAt: timestamp, answeredInRound: 1})
        );

        // Deploy quote price oracle
        MockChainlinkDataFeed quotePriceOracle = new MockChainlinkDataFeed();
        quotePriceOracle.setDecimals(xauDecimals);
        quotePriceOracle.setRoundData(
            1, RoundData({answer: quotePrice, startedAt: timestamp, updatedAt: timestamp, answeredInRound: 1})
        );
        // Set stale after times
        uint256 baseStaleAfter = 60 * 60; // 1 hour
        uint256 quoteStaleAfter = 48 * 60 * 60; // 48 hours

        // Deploy Chainlink Feed Price Oracle for base and quote
        address chainlinkFeedPriceOracleBase = address(
            new ChainlinkFeedPriceOracle(
                ChainlinkFeedPriceOracleConfig({feed: address(basePriceOracle), staleAfter: baseStaleAfter})
            )
        );
        address chainlinkFeedPriceOracleQuote = address(
            new ChainlinkFeedPriceOracle(
                ChainlinkFeedPriceOracleConfig({feed: address(quotePriceOracle), staleAfter: quoteStaleAfter})
            )
        );

        // Deploy TwoPriceOracle
        TwoPriceOracleConfig memory config =
            TwoPriceOracleConfig({base: chainlinkFeedPriceOracleBase, quote: chainlinkFeedPriceOracleQuote});
        twoPriceOracle = new TwoPriceOracle(config);

        return twoPriceOracle;
    }
}
