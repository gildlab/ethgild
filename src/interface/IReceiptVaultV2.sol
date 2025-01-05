// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IReceiptVaultV1} from "./deprecated/IReceiptVaultV1.sol";
import {IReceiptV2} from "./IReceiptV2.sol";

/// @title IReceiptVaultV2
/// @notice The `IReceiptVaultV2` interface extends `IReceiptVaultV1` with a
/// getter for the `receipt` contract. Otherwise it is identical to
/// `IReceiptVaultV1`.
interface IReceiptVaultV2 is IReceiptVaultV1 {
    /// @return The `IReceiptV2` contract that is the receipt for this vault.
    function receipt() external view returns (IReceiptV2);
}
