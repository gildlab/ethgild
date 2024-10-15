// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {Test, Vm} from "forge-std/Test.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    ERC20PriceOracleReceiptVault,
    ReceiptVaultConstructionConfig,
    ERC20PriceOracleReceiptVaultConfig
} from "src/concrete/vault/ERC20PriceOracleReceiptVault.sol";
import {LibERC20PriceOracleReceiptVaultCreator} from "../lib/LibERC20PriceOracleReceiptVaultCreator.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {TwoPriceOracle, TwoPriceOracleConfig} from "src/concrete/oracle/TwoPriceOracle.sol";
import {
    ChainlinkFeedPriceOracle,
    ChainlinkFeedPriceOracleConfig
} from "src/oracle/price/chainlink/ChainlinkFeedPriceOracle.sol";
import {MockChainlinkDataFeed, RoundData} from "test/concrete/MockChainlinkDataFeed.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract ERC20PriceOracleReceiptVaultTest is Test {
    event ERC20PriceOracleReceiptVaultInitialized(address sender, ERC20PriceOracleReceiptVaultConfig config);

    ICloneableFactoryV2 internal immutable iFactory;
    ERC20PriceOracleReceiptVault internal immutable iImplementation;
    ReceiptContract internal immutable iReceiptImplementation;
    IERC20 immutable iAsset;

    constructor() {
        iFactory = new CloneFactory();
        iReceiptImplementation = new ReceiptContract();
        iImplementation = new ERC20PriceOracleReceiptVault(
            ReceiptVaultConstructionConfig({factory: iFactory, receiptImplementation: iReceiptImplementation})
        );
        iAsset = IERC20(address(uint160(uint256(keccak256("asset.test")))));
    }

    function createVault(address priceOracle, string memory name, string memory symbol)
        internal
        returns (ERC20PriceOracleReceiptVault)
    {
        ERC20PriceOracleReceiptVault vault = LibERC20PriceOracleReceiptVaultCreator.createVault(
            iFactory, iImplementation, priceOracle, address(iAsset), name, symbol
        );
        return vault;
    }

    function createTwoPriceOracle(uint8 usdDecimals, uint8 xauDecimals, uint256 timestamp, uint80 answeredInRound)
        internal
        returns (TwoPriceOracle twoPriceOracle)
    {
        int256 basePrice = 1e8; // Example price for base
        int256 quotePrice = 1.8e8; // Example price for quote

        // Deploy base price oracle
        MockChainlinkDataFeed basePriceOracle = new MockChainlinkDataFeed();
        basePriceOracle.setDecimals(usdDecimals);
        basePriceOracle.setRoundData(
            1,
            RoundData({answer: basePrice, startedAt: timestamp, updatedAt: timestamp, answeredInRound: answeredInRound})
        );

        // Deploy quote price oracle
        MockChainlinkDataFeed quotePriceOracle = new MockChainlinkDataFeed();
        quotePriceOracle.setDecimals(xauDecimals);
        quotePriceOracle.setRoundData(
            1,
            RoundData({answer: quotePrice, startedAt: timestamp, updatedAt: timestamp, answeredInRound: answeredInRound})
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

    /// Get Receipt from event
    function getReceipt() internal returns (ReceiptContract) {
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the ERC20PriceOracleReceiptVaultInitialized event log
        address receiptAddress = address(0);
        bool eventFound = false; // Flag to indicate whether the event log was found
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == ERC20PriceOracleReceiptVaultInitialized.selector) {
                // Decode the event data
                (, ERC20PriceOracleReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, ERC20PriceOracleReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                eventFound = true; // Set the flag to true since event log was found
                break;
            }
        }
        // Assert that the event log was found
        assertTrue(eventFound, "ERC20PriceOracleReceiptVaultInitialized event log not found");
        // Return an receipt contract
        return ReceiptContract(receiptAddress);
    }
}
