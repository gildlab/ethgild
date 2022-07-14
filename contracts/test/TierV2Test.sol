// SPDX-License-Identifier: CAL
pragma solidity =0.8.10;

import {TierConstants} from "@beehiveinnovation/rain-protocol/contracts/tier/libraries/TierConstants.sol";

/// @title TierV2Test
contract TierV2Test {
    /// Either fetch the report from storage or return UNINITIALIZED.
    function report(address, uint256[] memory)
        public
        view
        virtual
        returns (uint256)
    {
        return TierConstants.NEVER_REPORT;
    }

    function reportTimeForTier(
        address,
        uint256,
        uint256[] calldata
    ) external view returns (uint256) {
        return block.timestamp;
    }
}
