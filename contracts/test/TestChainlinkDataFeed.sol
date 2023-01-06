// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Chainlink imports.
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/// Mimics round data for a chainlink oracle as a struct rather than tuple.
/// @param answer As per `AggregatorV3Interface.getRoundData`.
/// @param startedAt As per `AggregatorV3Interface.getRoundData`.
/// @param updatedAt As per `AggregatorV3Interface.getRoundData`.
/// @param answeredInRound As per `AggregatorV3Interface.getRoundData`.
struct RoundData {
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
}

/// @title TestChainlinkDataFeed
/// @notice Mock for a chainlink data feed.
/// TODO Autogenerate mocks e.g. https://github.com/defi-wonderland/smock
contract TestChainlinkDataFeed is AggregatorV3Interface {
    /// @dev internal state so mock can set decimals externally.
    uint8 private _decimals;
    string private _description;
    mapping(uint80 => RoundData) private _roundData;
    uint80 private _latestRoundId;
    uint256 private _version;

    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    function setDescription(string memory description_) public {
        _description = description_;
    }

    function setRoundData(uint80 roundId_, RoundData memory roundData_) public {
        _roundData[roundId_] = roundData_;
        // Treat this as the high water mark if appropriate.
        if (roundId_ > _latestRoundId) {
            _latestRoundId = roundId_;
        }
    }

    function setVersion(uint256 version_) public {
        _version = version_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function description() public view override returns (string memory) {
        return _description;
    }

    function getRoundData(
        uint80 roundId_
    ) public view override returns (uint80, int256, uint256, uint256, uint80) {
        RoundData memory roundData_ = _roundData[roundId_];
        return (
            roundId_,
            roundData_.answer,
            roundData_.startedAt,
            roundData_.updatedAt,
            roundData_.answeredInRound
        );
    }

    function latestRoundData()
        public
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return getRoundData(_latestRoundId);
    }

    function version() public view override returns (uint256) {
        return _version;
    }
}
