// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "../PriceOracleConstants.sol";
import "../IPriceOracle.sol";

/// https://docs.chain.link/docs/get-the-latest-price/#getting-a-different-price-denomination
contract ChainlinkFeedPriceOracle is IPriceOracle {
    event Construction(address sender, address feed);

    AggregatorV3Interface private immutable feed;

    constructor(address feed_) {
        feed = AggregatorV3Interface(feed_);
        emit Construction(msg.sender, feed_);
    }

    function price() external view override returns (uint256) {
        (, int256 price_, , , ) = feed.latestRoundData();
        require(price_ > 0, "MIN_BASE_PRICE");

        uint256 targetDecimals_ = PriceOracleConstants.DECIMALS;
        uint256 decimals_ = feed.decimals();

        if (targetDecimals_ > decimals_) {
            return uint256(price_) * 10**(targetDecimals_ - decimals_);
        } else if (decimals_ > targetDecimals_) {
            return uint256(price_) / 10**(decimals_ - targetDecimals_);
        }
        return uint256(price_);
    }
}
