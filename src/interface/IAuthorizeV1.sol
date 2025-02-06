// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

error Unauthorized(address user, bytes32 permission, bytes data);

interface IAuthorizeV1 {
    function authorize(address user, bytes32 permission, bytes memory data) external;
}
