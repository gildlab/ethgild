// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

/// Simplified interface into a price oracle.
/// The intention is that some more complex oracle interface such as chainlink
/// `AggregatorV3Interface` is wrapped/adapted by a contract that implements
/// `IPriceOracle` to produce a single final value.
///
/// Prices from an `IPriceOracle` MUST be:
/// - The latest available data/value
/// - Fresh enough or error if only too-stale data is available
/// - Represented as positive uint values only or error
/// - 18 decimal fixed point values representing a ratio (price) between "base"
/// and "quote" token.
///
/// If for any reason the underlying oracle cannot produce an appropriate
/// answer it MUST error rather than return inappropriate values. The ability
/// to do so MAY be limited by upstream providers (e.g. Chainlink silently
/// pausing price data during a heartbeat).
abstract contract IPriceOracle {
    /// Returns the current/latest price according to the oracle.
    function price() external view virtual returns (uint256 price_);
}
