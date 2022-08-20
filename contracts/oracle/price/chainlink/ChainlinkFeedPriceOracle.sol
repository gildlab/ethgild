// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@beehiveinnovation/rain-protocol/contracts/math/FixedPointMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";

import "../IPriceOracle.sol";

/// All data required to construct the contract.
/// @param feed The address of the underlying chainlink oracle.
/// @param staleAfter The duration after which price data will be considered
/// too stale for use and error.
struct ChainlinkFeedPriceOracleConstructionConfig {
    address feed;
    uint256 staleAfter;
}

/// @title ChainlinkFeedPriceOracle
/// @notice Converts a single chainlink price oracle to an `IPriceOracle`.
/// This involves:
/// - Fetching latest round data from chainlink
/// - Rejecting negative price values
/// - Fetching decimals from chainlink
/// - Rescaling chainlink price data to target decimals if required
contract ChainlinkFeedPriceOracle is IPriceOracle {
    using SafeCast for int256;
    using FixedPointMath for uint256;

    /// Emitted upon deployment and construction of oracle
    /// @param sender `msg.sender` that deploys the oracle.
    /// @param config All config used to construct the contract.
    event Construction(
        address sender,
        ChainlinkFeedPriceOracleConstructionConfig config
    );

    /// Immutable copy of `ConstructionConfig.feed`.
    AggregatorV3Interface public immutable feed;

    /// Immutable copy of `ConstructionConfig.staleAfter`.
    uint256 public immutable staleAfter;

    /// Constructor.
    /// @param config_ All config required to construct the contract.
    constructor(ChainlinkFeedPriceOracleConstructionConfig memory config_) {
        feed = AggregatorV3Interface(config_.feed);
        staleAfter = config_.staleAfter;
        emit Construction(msg.sender, config_);
    }

    /// @inheritdoc IPriceOracle
    function price() external view override returns (uint256 price_) {
        (, int256 answer_, , uint256 updatedAt_, ) = feed.latestRoundData();
        require(answer_ > 0, "MIN_BASE_PRICE");
        // Checked time comparison ensures no updates from the future as that
        // would overflow, and no stale prices.
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp - updatedAt_ < staleAfter, "STALE_PRICE");

        // Safely cast the answer to uint and scale it to 18 decimal FP.
        price_ = answer_.toUint256().scale18(feed.decimals());
    }
}
