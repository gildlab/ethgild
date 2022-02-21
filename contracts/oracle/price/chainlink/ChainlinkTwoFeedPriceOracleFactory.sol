// SPDX-License-Identifier: CAL
pragma solidity ^0.8.12;

import {Factory} from "@beehiveinnovation/rain-protocol/contracts/factory/Factory.sol";
import {ChainlinkTwoFeedPriceOracle, ChainlinkTwoFeedPriceOracleConfig} from "./ChainlinkTwoFeedPriceOracle.sol";

/// @title ChainlinkFeedPriceOracleFactory
/// @notice Factory for creating and deploying `ChainlinkFeedPriceOracle`.
contract ChainlinkFeedPriceOracleFactory is Factory {
    /// @inheritdoc Factory
    function _createChild(bytes calldata data_)
        internal
        virtual
        override
        returns (address)
    {
        // This is built directly with `new` instead of cloning as we're
        // optimizing for use of cheap immutables at runtime rather than cheap
        // deployments.
        return
            address(
                new ChainlinkTwoFeedPriceOracle(
                    abi.decode(data_, (ChainlinkTwoFeedPriceOracleConfig))
                )
            );
    }

    /// Typed wrapper for `createChild`.
    /// Use original `Factory` `createChild` function signature if function
    /// parameters are already encoded.
    ///
    /// @param config_ base and quote `address` of the price oracles.
    /// @return New `ChainlinkTwoFeedPriceOracle` child contract address.
    function createChildTyped(
        ChainlinkTwoFeedPriceOracleConfig calldata config_
    ) external returns (ChainlinkTwoFeedPriceOracle) {
        return
            ChainlinkTwoFeedPriceOracle(this.createChild(abi.encode(config_)));
    }
}
