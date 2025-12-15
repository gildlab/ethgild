// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// Thrown when constructing a deployer with a zero receipt implementation
/// address.
error ZeroReceiptImplementation();

/// Thrown when constructing a deployer with a zero vault implementation address.
error ZeroVaultImplementation();

/// Thrown when the beacon owner is set to the zero address.
error ZeroBeaconOwner();

/// Thrown when the initial admin is the zero address.
error ZeroInitialAdmin();

/// Thrown when attempting to initialize with a non-zero receipt address.
/// @param receipt The receipt address that is not zero in the initialization
/// config.
error InitializeNonZeroReceipt(address receipt);

/// Thrown when receipt initialization fails.
error InitializeReceiptFailed();

/// Thrown when vault initialization fails.
error InitializeVaultFailed();
