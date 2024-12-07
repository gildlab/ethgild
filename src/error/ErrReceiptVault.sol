// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when an ID can't be deposited or withdrawn.
/// @param id The invalid ID.
error InvalidId(uint256 id);

/// Thrown when the share ratio does not meet the minimum share ratio.
/// @param minShareRatio The minimum share ratio.
/// @param shareRatio The actual share ratio.
error MinShareRatio(uint256 minShareRatio, uint256 shareRatio);

/// Thrown when depositing 0 asset amount.
error ZeroAssetsAmount();

/// Thrown when minting 0 shares amount.
error ZeroSharesAmount();

/// Thrown when receiver of minted shares is address zero.
error ZeroReceiver();

/// Thrown when owner of shares withdrawn is address zero.
error ZeroOwner();

/// Thrown when depositing assets under ID zero.
error ZeroID();

/// Thrown when the receipt has the wrong owner on initialization.
/// @param expectedOwner The expected owner.
/// @param actualOwner The actual owner.
error WrongOwner(address expectedOwner, address actualOwner);

/// Thrown when the receipt vault does not manage the receipt.
/// @param expectedManager The expected manager.
/// @param actualManager The actual manager.
error WrongManager(address expectedManager, address actualManager);
