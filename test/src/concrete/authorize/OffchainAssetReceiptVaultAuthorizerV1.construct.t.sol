// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config,
    CERTIFY_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    DEPOSIT_ADMIN,
    WITHDRAW_ADMIN,
    FREEZE_HANDLER_ADMIN,
    FREEZE_HANDLER,
    CERTIFY,
    CONFISCATE_SHARES,
    CONFISCATE_RECEIPT,
    DEPOSIT,
    WITHDRAW,
    ZeroInitialAdmin,
    ZeroAuthorizee
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";

contract OffchainAssetReceiptVaultAuthorizerV1ConstructTest is Test {
    function testOffchainAssetReceiptVaultAuthorizerV1Construct(address initialAdmin, address authorizee) external {
        OffchainAssetReceiptVaultAuthorizerV1 authorizer = new OffchainAssetReceiptVaultAuthorizerV1();

        vm.expectRevert("Initializable: contract is already initialized");
        authorizer.initialize(
            abi.encode(
                OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee})
            )
        );
    }

    function testOffchainAssetReceiptVaultAuthorizerV1Initialize(
        address initialAdmin,
        address authorizee,
        bytes32 badRole
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(authorizee != address(0));
        vm.assume(initialAdmin != authorizee);
        vm.assume(badRole != CERTIFY_ADMIN);
        vm.assume(badRole != CONFISCATE_SHARES_ADMIN);
        vm.assume(badRole != CONFISCATE_RECEIPT_ADMIN);
        vm.assume(badRole != DEPOSIT_ADMIN);
        vm.assume(badRole != WITHDRAW_ADMIN);
        vm.assume(badRole != FREEZE_HANDLER_ADMIN);
        vm.assume(badRole != CERTIFY);
        vm.assume(badRole != CONFISCATE_SHARES);
        vm.assume(badRole != CONFISCATE_RECEIPT);
        vm.assume(badRole != DEPOSIT);
        vm.assume(badRole != WITHDRAW);
        vm.assume(badRole != FREEZE_HANDLER);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: authorizee})
        );

        vm.expectRevert("Initializable: contract is already initialized");
        authorizerImplementation.initialize(initData);

        CloneFactory factory = new CloneFactory();

        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), initData));

        vm.assertTrue(authorizer.hasRole(CERTIFY_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_SHARES_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_RECEIPT_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(DEPOSIT_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(WITHDRAW_ADMIN, initialAdmin));
        vm.assertTrue(authorizer.hasRole(FREEZE_HANDLER_ADMIN, initialAdmin));

        vm.assertTrue(!authorizer.hasRole(CERTIFY, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_SHARES, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_RECEIPT, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(DEPOSIT, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(WITHDRAW, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(FREEZE_HANDLER, initialAdmin));
        vm.assertTrue(!authorizer.hasRole(badRole, initialAdmin));

        vm.assertTrue(!authorizer.hasRole(CERTIFY_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_SHARES_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_RECEIPT_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(DEPOSIT_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(WITHDRAW_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(FREEZE_HANDLER_ADMIN, authorizee));
        vm.assertTrue(!authorizer.hasRole(badRole, authorizee));

        vm.assertTrue(!authorizer.hasRole(CERTIFY, authorizee));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_SHARES, authorizee));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_RECEIPT, authorizee));
        vm.assertTrue(!authorizer.hasRole(DEPOSIT, authorizee));
        vm.assertTrue(!authorizer.hasRole(WITHDRAW, authorizee));
        vm.assertTrue(!authorizer.hasRole(FREEZE_HANDLER, authorizee));
        vm.assertTrue(!authorizer.hasRole(badRole, authorizee));

        vm.startPrank(initialAdmin);
        authorizer.grantRole(CERTIFY, authorizee);
        authorizer.grantRole(CONFISCATE_SHARES, authorizee);
        authorizer.grantRole(CONFISCATE_RECEIPT, authorizee);
        authorizer.grantRole(DEPOSIT, authorizee);
        authorizer.grantRole(WITHDRAW, authorizee);
        authorizer.grantRole(FREEZE_HANDLER, authorizee);
        vm.stopPrank();

        vm.assertTrue(authorizer.hasRole(CERTIFY, authorizee));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_SHARES, authorizee));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_RECEIPT, authorizee));
        vm.assertTrue(authorizer.hasRole(DEPOSIT, authorizee));
        vm.assertTrue(authorizer.hasRole(WITHDRAW, authorizee));
        vm.assertTrue(authorizer.hasRole(FREEZE_HANDLER, authorizee));
    }

    function testOffchainAssetReceiptVaultAuthorizerV1InitializeZeroAdmin(address authorizee) external {
        vm.assume(authorizee != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        bytes memory initData =
            abi.encode(OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: address(0), authorizee: authorizee}));

        CloneFactory factory = new CloneFactory();

        vm.expectRevert(ZeroInitialAdmin.selector);
        OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), initData));
    }

    function testOffchainAssetReceiptVaultAuthorizerV1InitializeZeroAuthorizee(address initialAdmin) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin, authorizee: address(0)})
        );

        CloneFactory factory = new CloneFactory();

        vm.expectRevert(ZeroAuthorizee.selector);
        OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), initData));
    }
}
