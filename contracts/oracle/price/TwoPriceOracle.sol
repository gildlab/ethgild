// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "./IPriceOracleV1.sol";
import "@rainprotocol/rain-protocol/contracts/math/FixedPointMath.sol";

/// Construction config for `TwoPriceOracle`.
/// @param base The base price of the merged pair, will be the numerator.
/// @param quote The quote price of the merged pair, will be the denominator.
struct TwoPriceOracleConfig {
    address base;
    address quote;
}

/// @title TwoPriceOracle
/// Any time we have two price feeds that share a denominator we can derive the
/// price of the numerators by dividing the two ratios. We leverage the fixed
/// point 18 decimal normalisation from `IPriceOracleV1.price` to simplify this
/// logic to a single `fixedPointDiv` call here.
///
/// For example, an ETH/USD (base) and an XAU/USD (quote) price can be combined
/// to a single ETH/XAU price as (ETH/USD) / (XAU/USD).
contract TwoPriceOracle is IPriceOracleV1 {
    using FixedPointMath for uint256;

    /// Emitted upon deployment and construction.
    event Construction(address sender, TwoPriceOracleConfig config);

    /// As per `ConstructionConfig.base`.
    IPriceOracleV1 public immutable base;
    /// As per `ConstructionConfig.quote`.
    IPriceOracleV1 public immutable quote;

    /// @param config_ Config required to construct.
    constructor(TwoPriceOracleConfig memory config_) {
        base = IPriceOracleV1(config_.base);
        quote = IPriceOracleV1(config_.quote);
        emit Construction(msg.sender, config_);
    }

    /// Calculates the price as `base / quote` using fixed point 18 decimal math.
    /// Round UP to avoid edge cases that could return `0` which is disallowed
    /// by `IPriceOracleV1` despite compliant sub-oracles.
    /// @inheritdoc IPriceOracleV1
    function price() external view override returns (uint256) {
        return base.price().fixedPointDiv(quote.price(), Math.Rounding.Up);
    }
}
