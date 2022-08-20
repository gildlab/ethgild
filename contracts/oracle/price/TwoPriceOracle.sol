// SPDX-License-Identifier: UNLICENSE
pragma solidity =0.8.10;

import "./IPriceOracle.sol";
import "@beehiveinnovation/rain-protocol/contracts/math/FixedPointMath.sol";

/// All config required for construction.
/// @param base The base price of the merged pair, will be the numerator.
/// @param quote The quote price of the merged pair, will be the denominator.
struct TwoPriceOracleConstructionConfig {
    address base;
    address quote;
}

/// @title TwoPriceOracle
/// Any time we have two price feeds that share a denominator we can calculate
/// a single price by dividing them.
///
/// For example, an ETH/USD (base) and an XAU/USD (quote) price can be combined
/// to a single ETH/XAU price as (ETH/USD) / (XAU/USD).
contract TwoPriceOracle is IPriceOracle {
    using FixedPointMath for uint256;

    /// Emitted upon deployment and construction.
    event Construction(address sender, TwoPriceOracleConstructionConfig config);

    /// As per `ConstructionConfig.base`.
    IPriceOracle public immutable base;
    /// As per `ConstructionConfig.quote`.
    IPriceOracle public immutable quote;

    /// Constructor.
    /// @param config_ All configr required to construct.
    constructor(TwoPriceOracleConstructionConfig memory config_) {
        base = IPriceOracle(config_.base);
        quote = IPriceOracle(config_.quote);
        emit Construction(msg.sender, config_);
    }

    /// Calculates the price as `base / quote`.
    /// @inheritdoc IPriceOracle
    function price() external view override returns (uint256 price_) {
        price_ = base.price().fixedPointDiv(quote.price());
    }
}
