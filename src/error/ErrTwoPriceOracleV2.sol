// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when the base and quote are the same address.
/// @param base The address that was the same as `quote`.
error ErrTwoPriceOracleV2SameQuoteBase(address base);
