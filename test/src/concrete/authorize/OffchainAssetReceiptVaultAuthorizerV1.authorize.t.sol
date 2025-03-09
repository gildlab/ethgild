// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    TRANSFER_SHARES,
    TRANSFER_RECEIPT,
    CERTIFY,
    ZeroInitialAdmin,
    ZeroAuthorizee,
    Unauthorized,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    DEPOSIT,
    WITHDRAW,
    FREEZE_HANDLER
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {TransferSharesStateChange, TransferReceiptStateChange} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultAuthorizerV1AuthorizeTest is Test {
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
        address initialAdmin,
        address authorizee,
        address user,
        bytes32 permission,
        bytes memory data
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(authorizee != address(0));
        vm.assume(initialAdmin != authorizee);

        vm.assume(permission != TRANSFER_SHARES);
        vm.assume(permission != TRANSFER_RECEIPT);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        vm.startPrank(authorizee);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        authorizer.authorize(user, permission, data);
        vm.stopPrank();
    }

    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeAuthorized(
        address initialAdmin,
        address authorizee,
        address user,
        bytes memory data
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(authorizee != address(0));
        vm.assume(initialAdmin != authorizee);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes32[] memory roles = new bytes32[](6);
        roles[0] = CERTIFY;
        roles[1] = CONFISCATE_SHARES;
        roles[2] = CONFISCATE_RECEIPT;
        roles[3] = DEPOSIT;
        roles[4] = WITHDRAW;
        roles[5] = FREEZE_HANDLER;

        for (uint256 i = 0; i < roles.length; i++) {
            vm.assertTrue(!authorizer.hasRole(roles[i], user));
            vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, roles[i], data));
            authorizer.authorize(user, roles[i], data);
            vm.startPrank(initialAdmin);
            authorizer.grantRole(roles[i], user);
            vm.stopPrank();
            authorizer.authorize(user, roles[i], data);
        }
    }

    /// When certification is NOT expired then all TRANSFER_SHARES are
    /// authorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyNotExpired(
        address initialAdmin,
        address authorizee,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(authorizee != address(0));
        vm.assume(initialAdmin != authorizee);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        authorizer.authorize(
            user,
            TRANSFER_SHARES,
            abi.encode(TransferSharesStateChange({from: from, to: to, amount: amount, isCertificationExpired: false}))
        );
    }

    /// When certification is NOT expired then all TRANSFER_RECEIPT are
    /// authorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyNotExpired(
        address initialAdmin,
        address authorizee,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(authorizee != address(0));
        vm.assume(initialAdmin != authorizee);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        authorizer.authorize(
            user,
            TRANSFER_RECEIPT,
            abi.encode(
                TransferReceiptStateChange({
                    from: from,
                    to: to,
                    ids: ids,
                    amounts: amounts,
                    isCertificationExpired: false
                })
            )
        );
    }
}
