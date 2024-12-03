// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 thedavidmeister
pragma solidity =0.8.25;

import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {PriceOracleV2, IPriceOracleV2} from "../../abstract/PriceOracleV2.sol";

/// Construction config for `TwoPriceOracle`.
/// @param base The base price of the merged pair, will be the numerator.
/// @param quote The quote price of the merged pair, will be the denominator.
struct TwoPriceOracleConfigV2 {
    IPriceOracleV2 base;
    IPriceOracleV2 quote;
}

/// @title TwoPriceOracle
/// Any time we have two price feeds that share a denominator we can derive the
/// price of the numerators by dividing the two ratios. We leverage the fixed
/// point 18 decimal normalisation from `IPriceOracleV2.price` to simplify this
/// logic to a single `fixedPointDiv` call here.
///
/// For example, an ETH/USD (base) and an XAU/USD (quote) price can be combined
/// to a single ETH/XAU price as (ETH/USD) / (XAU/USD).
contract TwoPriceOracleV2 is PriceOracleV2 {
    using LibFixedPointDecimalArithmeticOpenZeppelin for uint256;

    /// Emitted upon deployment and construction.
    event Construction(address sender, TwoPriceOracleConfigV2 config);

    /// As per `ConstructionConfig.base`.
    IPriceOracleV2 public immutable base;
    /// As per `ConstructionConfig.quote`.
    IPriceOracleV2 public immutable quote;

    /// @param config Config required to construct.
    constructor(TwoPriceOracleConfigV2 memory config) {
        base = IPriceOracleV2(config.base);
        quote = IPriceOracleV2(config.quote);
        emit Construction(msg.sender, config);

        // Dry run the price to flush out any trivial issues with the oracles
        // that cause errors, such as a zero address or corrupted oracle.
        // This is not a perfect test, as an arbitrary contract MAY return a
        // value for `price` that is not valid according to the `IPriceOracleV2`
        // interface, but it should flush out most basic configuration mistakes.
        uint256 price = _price();
        (price);
    }

    /// Calculates the price as `base / quote` using fixed point 18 decimal math.
    /// Round UP to avoid edge cases that could return `0` which is disallowed
    /// by `IPriceOracleV2` despite compliant sub-oracles.
    /// @inheritdoc PriceOracleV2
    function _price() internal virtual override returns (uint256) {
        // This contract is never intended to hold gas, it's only here to pay the
        // oracles that might need to be paid.
        // This means the slither detector here is a false positive.
        //slither-disable-next-line arbitrary-send-eth
        uint256 quotePrice = quote.price{value: address(this).balance}();
        //slither-disable-next-line arbitrary-send-eth
        uint256 basePrice = base.price{value: address(this).balance}();
        return basePrice.fixedPointDiv(quotePrice, Math.Rounding.Up);
    }
}
