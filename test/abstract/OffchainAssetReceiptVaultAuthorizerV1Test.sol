// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";

import {IAuthorizeV1, Unauthorized} from "src/interface/IAuthorizeV1.sol";
import {TRANSFER_SHARES, TRANSFER_RECEIPT} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAccessControlUpgradeable as IAccessControl} from
    "openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol";
import {TransferSharesStateChange, TransferReceiptStateChange} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultAuthorizerV1Test is Test {
    function checkDefaultOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
        IAuthorizeV1 authorizer,
        address sender,
        address user,
        bytes32 permission,
        bytes memory data
    ) internal {
        vm.assume(permission != TRANSFER_SHARES);
        vm.assume(permission != TRANSFER_RECEIPT);

        vm.startPrank(sender);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        authorizer.authorize(user, permission, data);
        vm.stopPrank();
    }

    function checkRolesAuthorized(
        IAuthorizeV1 authorizer,
        address admin,
        address sender,
        address user,
        bytes memory data,
        bytes32[] memory roles
    ) internal {
        for (uint256 i = 0; i < roles.length; i++) {
            vm.startPrank(sender);
            vm.assertTrue(!IAccessControl(address(authorizer)).hasRole(roles[i], user));
            vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, roles[i], data));
            authorizer.authorize(user, roles[i], data);
            vm.stopPrank();

            vm.startPrank(admin);
            IAccessControl(address(authorizer)).grantRole(roles[i], user);
            vm.stopPrank();

            vm.startPrank(sender);
            authorizer.authorize(user, roles[i], data);
            vm.stopPrank();
        }
    }

    function checkAuthorizeTransferSharesCertifyNotExpired(
        IAuthorizeV1 authorizer,
        address sender,
        address user,
        address from,
        address to,
        uint256 amount
    ) internal {
        vm.startPrank(sender);
        authorizer.authorize(
            user,
            TRANSFER_SHARES,
            abi.encode(TransferSharesStateChange({from: from, to: to, amount: amount, isCertificationExpired: false}))
        );
        vm.stopPrank();
    }
}
