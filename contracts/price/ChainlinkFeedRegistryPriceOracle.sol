// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import "@chainlink/contracts/src/v0.8/Denominations.sol";

import "./IPriceOracle.sol";

/// Oracle addresses change on every network so we allow them to be set in the
/// constructor as immutables.
struct ChainlinkFeedRegistryPriceOracleConfig {
    address registry;
    address base;
    address quote;
}

contract ChainlinkFeedRegistryPriceOracle is IPriceOracle {
    event Construction(
        address sender,
        ChainlinkFeedRegistryPriceOracleConfig config
    );

    FeedRegistryInterface private immutable registry;
    address private immutable base;
    address private immutable quote;

    constructor(ChainlinkFeedRegistryPriceOracleConfig memory config_) {
        registry = FeedRegistryInterface(config_.registry);
        base = config_.base;
        quote = config_.quote;
    }

    function price() external view override returns (uint8, uint256) {
        (, int256 price_, , , ) = registry.latestRoundData(base, quote);
        require(price_ >= 0, "NEGATIVE_PRICE");
        return (registry.decimals(base, quote), uint256(price_));
    }
}
