// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../PriceOracleConstants.sol";
import "../IPriceOracle.sol";

/// Oracle addresses change on every network so we allow them to be set in the
/// constructor as immutables.
struct ChainlinkTwoFeedPriceOracleConfig {
    address base;
    address quote;
}

/// https://docs.chain.link/docs/get-the-latest-price/#getting-a-different-price-denomination
contract ChainlinkTwoFeedPriceOracle is IPriceOracle {
    event Construction(
        address sender,
        ChainlinkTwoFeedPriceOracleConfig config
    );

    AggregatorV3Interface private immutable base;
    AggregatorV3Interface private immutable quote;

    constructor(ChainlinkTwoFeedPriceOracleConfig memory config_) {
        base = AggregatorV3Interface(config_.base);
        quote = AggregatorV3Interface(config_.quote);
    }

    function price() external view override returns (uint256) {
        (, int256 basePrice_, , , ) = base.latestRoundData();
        (, int256 quotePrice_, , , ) = quote.latestRoundData();
        require(basePrice_ > 0, "MIN_BASE_PRICE");
        require(quotePrice_ > 0, "MIN_QUOTE_PRICE");

        // We will be dividing by the quote price so we need to add its
        // decimals to the target.
        uint256 targetDecimals_ = PriceOracleConstants.DECIMALS +
            quote.decimals();
        uint256 decimals_ = base.decimals();

        if (targetDecimals_ > decimals_) {
            return
                (uint256(basePrice_) * 10**(targetDecimals_ - decimals_)) /
                uint256(quotePrice_);
        } else if (decimals_ > targetDecimals_) {
            return
                uint256(basePrice_) /
                (uint256(quotePrice_) * 10**(decimals_ - targetDecimals_));
        }
        return uint256(basePrice_) / uint256(quotePrice_);
    }
}
