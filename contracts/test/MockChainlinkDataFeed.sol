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

/// @title MockChainlinkDataFeed
/// @notice Mock for a chainlink data feed.
/// TODO Autogenerate mocks e.g. https://github.com/defi-wonderland/smock
contract MockChainlinkDataFeed is AggregatorV3Interface {
    /// @dev mock can set decimals.
    uint8 private _decimals;
    /// @dev mock can set description.
    string private _description;
    /// @dev mock can set rounds.
    mapping(uint80 => RoundData) private _roundData;
    /// @dev mock can set latest round id.
    uint80 private _latestRoundId;
    /// @dev mock can set version.
    uint256 private _version;

    /// Setter for _decimals.
    /// @param decimals_ The new value for _decimals.
    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    /// Setter for _description.
    /// @param description_ The new value for _description.
    function setDescription(string memory description_) external {
        _description = description_;
    }

    /// Upsert some round data.
    /// Updates `_latestRoundId` if the round id is larger.
    /// @param roundId_ The round id to set roundData_ for.
    /// @param roundData_ The data for this round.
    function setRoundData(
        uint80 roundId_,
        RoundData memory roundData_
    ) external {
        _roundData[roundId_] = roundData_;
        // Treat this as the high water mark if appropriate.
        if (roundId_ > _latestRoundId) {
            _latestRoundId = roundId_;
        }
    }

    /// Setter for _version.
    /// @param version_ The new value for _version.
    function setVersion(uint256 version_) external {
        _version = version_;
    }

    /// @inheritdoc AggregatorV3Interface
    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    /// @inheritdoc AggregatorV3Interface
    function description() external view override returns (string memory) {
        return _description;
    }

    /// @inheritdoc AggregatorV3Interface
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

    /// @inheritdoc AggregatorV3Interface
    function latestRoundData()
        external
        view
        override
        returns (uint80, int256, uint256, uint256, uint80)
    {
        return getRoundData(_latestRoundId);
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external view override returns (uint256) {
        return _version;
    }
}
