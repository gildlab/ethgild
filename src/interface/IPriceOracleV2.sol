// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

/// Simplified interface into a price oracle.
/// The intention is that some more complex oracle interface is wrapped/adapted
/// by a contract that implements `IPriceOracleV2` to produce a single final
/// price value. A price is defined as the best possible ratio between two assets
/// for the purpose of a liquid trade.
///
/// Prices from an `IPriceOracleV2` MUST be:
/// - The latest available data/value
/// - Fresh enough or revert if only too-stale data is available
/// - Represented as `uint256` values or error (e.g. disallow negative values)
/// - 18 decimal fixed point values representing a ratio (price) between "base"
/// and "quote" token.
/// - A positive integer, `0` prices are disallowed.
/// - Valid according to the upstream oracle or revert for any other reason the
/// price is suspect or unusable.
///
/// By normalising all ratios to 18 decimal fixed point at their source we
/// simplify downstream math that derives prices by combining several
/// real price quotes.
///
/// If for any reason the underlying oracle cannot produce an appropriate
/// answer it MUST error rather than return inappropriate values. The ability
/// to do so MAY be limited by upstream providers.
interface IPriceOracleV2 {
    /// Returns the current/latest price according to the oracle.
    function price() external payable returns (uint256);

    /// Need to accept refunds from the oracle.
    fallback() external payable;

    /// Need to accept refunds from the oracle.
    receive() external payable;
}
