// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {AccessControlUpgradeable as AccessControl} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";

/// Thrown when the admin is address zero.
error ZeroInitialAdmin();

/// @dev Rolename for certifiers.
/// Certifier role is required to extend the `certifiedUntil` time.
bytes32 constant CERTIFIER = keccak256("CERTIFIER");
/// @dev Rolename for certifier admins.
bytes32 constant CERTIFIER_ADMIN = keccak256("CERTIFIER_ADMIN");

/// @dev Configuration for the OffchainAssetReceiptVaultAuthorizorV1.
/// @param initialAdmin The initial admin of the contract.
struct OffchainAssetReceiptVaultAuthorizorV1Config {
    address initialAdmin;
}

/// @title OffchainAssetReceiptVaultAuthorizorV1
/// Implements the IAuthorizeV1 interface and provides a simple role based
/// access control for the OffchainAssetReceiptVault.
contract OffchainAssetReceiptVaultAuthorizorV1 is IAuthorizeV1, ICloneableV2, AccessControl {
    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes memory data) public initializer returns (bytes32) {
        OffchainAssetReceiptVaultAuthorizorV1Config memory config =
            abi.decode(data, (OffchainAssetReceiptVaultAuthorizorV1Config));

        __AccessControl_init();

        // The config admin MUST be set.
        if (config.initialAdmin == address(0)) {
            revert ZeroInitialAdmin();
        }

        // Define all admin roles. Note that admins can admin each other which
        // is a double edged sword. ANY admin can forcibly take over the entire
        // role by removing all other admins.
        _setRoleAdmin(CERTIFIER, CERTIFIER_ADMIN);
        _setRoleAdmin(CERTIFIER_ADMIN, CERTIFIER_ADMIN);

        _grantRole(CERTIFIER_ADMIN, config.initialAdmin);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// Permissions are treated as roles in this implementation. This makes the
    /// implementation roughly equivalent overall to the `onlyRole` modifier in
    /// OpenZeppelin's AccessControl.
    /// @inheritdoc IAuthorizeV1
    function authorize(address user, bytes32 permission, bytes calldata data) external view override {
        if (hasRole(permission, user)) {
            return;
        }

        revert Unauthorized(user, permission, data);
    }
}
