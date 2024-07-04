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
import {TestErc20} from "contracts/test/TestErc20.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "contracts/oracle/price/TwoPriceOracle.sol";
import {
    ChainlinkFeedPriceOracle,
    ChainlinkFeedPriceOracleConfig
} from "contracts/oracle/price/chainlink/ChainlinkFeedPriceOracle.sol";
import {MockChainlinkDataFeed, RoundData} from "contracts/test/MockChainlinkDataFeed.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    ICloneableFactoryV2 internal immutable iFactory;
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable receiptImplementation;

    constructor() {
        iFactory = new CloneFactory();
        receiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: receiptImplementation})
        );
    }

    function createVault(address priceOracle, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault, TestErc20)
    {
        TestErc20 asset = new TestErc20();
        ERC20PriceOracleReceiptVault vault = LibERC20PriceOracleReceiptVaultCreator.createVault(
            iFactory, iImplementation, priceOracle, address(asset), name, symbol
        );
        return (vault, asset);
    }

    function createTwoPriceOracle() internal returns (TwoPriceOracle twoPriceOracle) {
        uint8 usdDecimals = 8;
        uint8 xauDecimals = 8;
        int256 basePrice = 1e8; // Example price for base
        int256 quotePrice = 1.8e8; // Example price for quote
        uint256 now_ = block.timestamp;

        // Deploy base price oracle
        MockChainlinkDataFeed basePriceOracle = new MockChainlinkDataFeed();
        basePriceOracle.setDecimals(usdDecimals);
        basePriceOracle.setRoundData(
            1, RoundData({answer: basePrice, startedAt: now_, updatedAt: now_, answeredInRound: 1})
        );

        // Deploy quote price oracle
        MockChainlinkDataFeed quotePriceOracle = new MockChainlinkDataFeed();
        quotePriceOracle.setDecimals(xauDecimals);
        quotePriceOracle.setRoundData(
            1, RoundData({answer: quotePrice, startedAt: now_, updatedAt: now_, answeredInRound: 1})
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
