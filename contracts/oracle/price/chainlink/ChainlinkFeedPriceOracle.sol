// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "@rainprotocol/rain-protocol/contracts/chainlink/LibChainlink.sol";

import "../IPriceOracleV1.sol";

/// Config for construction of `ChainlinkFeedPriceOracle`.
/// @param feed The address of the underlying Chainlink oracle.
/// @param staleAfter The duration in seconds after which price data will be
/// considered too stale for use and error.
struct ChainlinkFeedPriceOracleConfig {
    address feed;
    uint256 staleAfter;
}

/// @title ChainlinkFeedPriceOracle
/// @notice Converts a single Chainlink price oracle to an `IPriceOracleV1`.
/// This involves:
/// - Fetching latest round data from Chainlink
/// - Rejecting negative price values
/// - Fetching decimals from Chainlink
/// - Rescaling Chainlink price data to target decimals if required.
contract ChainlinkFeedPriceOracle is IPriceOracleV1 {
    /// Emitted upon deployment and construction of oracle.
    /// @param sender `msg.sender` that deploys the oracle.
    /// @param config All config used to construct the contract.
    event Construction(address sender, ChainlinkFeedPriceOracleConfig config);

    /// Immutable copy of `ConstructionConfig.feed`.
    address public immutable feed;

    /// Immutable copy of `ConstructionConfig.staleAfter`.
    uint256 public immutable staleAfter;

    /// @param config_ Config required to interface with Chainlink.
    constructor(ChainlinkFeedPriceOracleConfig memory config_) {
        feed = config_.feed;
        staleAfter = config_.staleAfter;
        emit Construction(msg.sender, config_);
    }

    /// @inheritdoc IPriceOracleV1
    function price() external view virtual returns (uint256) {
        return LibChainlink.price(feed, staleAfter);
    }
}
