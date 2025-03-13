// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.0;

import {IReceiptVaultV1} from "./deprecated/IReceiptVaultV1.sol";
import {IReceiptV3} from "./IReceiptV3.sol";

/// @title IReceiptVaultV3
/// @notice The `IReceiptVaultV3` interface extends `IReceiptVaultV1` with a
/// getter for the `receipt` contract. Otherwise it is identical to
/// `IReceiptVaultV1`.
interface IReceiptVaultV3 is IReceiptVaultV1 {
    /// @return The `IReceiptV3` contract that is the receipt for this vault.
    function receipt() external view returns (IReceiptV3);
}
