// SPDX-License-Identifier: CAL
pragma solidity =0.8.25;

import {IPriceOracleV2} from "../../interface/IPriceOracleV2.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";

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
/// point 18 decimal normalisation from `IPriceOracleV2.price` to simplify this
/// logic to a single `fixedPointDiv` call here.
///
/// For example, an ETH/USD (base) and an XAU/USD (quote) price can be combined
/// to a single ETH/XAU price as (ETH/USD) / (XAU/USD).
contract TwoPriceOracle is IPriceOracleV2 {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Emitted upon deployment and construction.
    event Construction(address sender, TwoPriceOracleConfig config);

    /// As per `ConstructionConfig.base`.
    IPriceOracleV2 public immutable base;
    /// As per `ConstructionConfig.quote`.
    IPriceOracleV2 public immutable quote;

    /// @param config Config required to construct.
    constructor(TwoPriceOracleConfig memory config) {
        base = IPriceOracleV2(config.base);
        quote = IPriceOracleV2(config.quote);
        emit Construction(msg.sender, config);
    }

    /// Calculates the price as `base / quote` using fixed point 18 decimal math.
    /// Round UP to avoid edge cases that could return `0` which is disallowed
    /// by `IPriceOracleV2` despite compliant sub-oracles.
    /// @inheritdoc IPriceOracleV2
    function price() external payable override returns (uint256) {
        return base.price().fixedPointDiv(quote.price(), Math.Rounding.Up);
    }
}
