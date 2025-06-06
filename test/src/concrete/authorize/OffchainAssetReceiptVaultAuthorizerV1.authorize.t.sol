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
    Unauthorized,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    DEPOSIT,
    WITHDRAW,
    CertificationExpired
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {TransferSharesStateChange, TransferReceiptStateChange} from "src/concrete/vault/OffchainAssetReceiptVault.sol";

contract OffchainAssetReceiptVaultAuthorizerV1AuthorizeTest is Test {
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
        address initialAdmin,
        address user,
        bytes32 permission,
        bytes memory data
    ) external {
        vm.assume(initialAdmin != address(0));

        vm.assume(permission != TRANSFER_SHARES);
        vm.assume(permission != TRANSFER_RECEIPT);

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        authorizer.authorize(user, permission, data);
        vm.stopPrank();
    }

    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeAuthorized(
        address initialAdmin,
        address user,
        bytes memory data
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes32[] memory roles = new bytes32[](5);
        roles[0] = CERTIFY;
        roles[1] = CONFISCATE_SHARES;
        roles[2] = CONFISCATE_RECEIPT;
        roles[3] = DEPOSIT;
        roles[4] = WITHDRAW;

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
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

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
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

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

    /// When certification IS expired and this is not a mint or burn, and there
    /// are no other roles, then TRANSFER_SHARES is unauthorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpired(
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, to));
        authorizer.authorize(
            user,
            TRANSFER_SHARES,
            abi.encode(TransferSharesStateChange({from: from, to: to, amount: amount, isCertificationExpired: true}))
        );
    }

    /// When certification IS expired and this is not a mint or burn, and there
    /// are no other roles, then TRANSFER_RECEIPT is unauthorized.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpired(
        address initialAdmin,
        address user,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, to));
        authorizer.authorize(
            user,
            TRANSFER_RECEIPT,
            abi.encode(
                TransferReceiptStateChange({
                    from: from,
                    to: to,
                    ids: ids,
                    amounts: amounts,
                    isCertificationExpired: true
                })
            )
        );
    }

    /// If the certification is expired and this is a mint then TRANSFER_SHARES
    /// is authorized depending on the DEPOSIT role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpiredMintBurn(
        address initialAdmin,
        address user,
        address to,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(to != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes memory data = abi.encode(
            TransferSharesStateChange({from: address(0), to: to, amount: amount, isCertificationExpired: true})
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        // Withdraw does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, to);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, to);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_SHARES, data);
    }

    /// If the certification is expired and this is a mint then TRANSFER_RECEIPT
    /// is authorized depending on the DEPOSIT role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpiredMintBurn(
        address initialAdmin,
        address user,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(to != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes memory data = abi.encode(
            TransferReceiptStateChange({
                from: address(0),
                to: to,
                ids: ids,
                amounts: amounts,
                isCertificationExpired: true
            })
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        // Withdraw does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, to);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, address(0), to));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, to);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_RECEIPT, data);
    }

    /// If the certification is expired and this is a burn then TRANSFER_SHARES
    /// is authorized depending on the WITHDRAW role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferSharesCertifyExpiredBurn(
        address initialAdmin,
        address user,
        address from,
        uint256 amount
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(from != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes memory data = abi.encode(
            TransferSharesStateChange({from: from, to: address(0), amount: amount, isCertificationExpired: true})
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        // Deposit does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, from);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_SHARES, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, from);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_SHARES, data);
    }

    /// If the certification is expired and this is a burn then TRANSFER_RECEIPT
    /// is authorized depending on the WITHDRAW role.
    function testOffchainAssetReceiptVaultAuthorizerV1AuthorizeTransferReceiptCertifyExpiredBurn(
        address initialAdmin,
        address user,
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external {
        vm.assume(initialAdmin != address(0));
        vm.assume(from != address(0));

        OffchainAssetReceiptVaultAuthorizerV1 authorizerImplementation = new OffchainAssetReceiptVaultAuthorizerV1();

        OffchainAssetReceiptVaultAuthorizerV1Config memory config =
            OffchainAssetReceiptVaultAuthorizerV1Config({initialAdmin: initialAdmin});

        CloneFactory factory = new CloneFactory();
        OffchainAssetReceiptVaultAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultAuthorizerV1(factory.clone(address(authorizerImplementation), abi.encode(config)));

        bytes memory data = abi.encode(
            TransferReceiptStateChange({
                from: from,
                to: address(0),
                ids: ids,
                amounts: amounts,
                isCertificationExpired: true
            })
        );

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        // Deposit does nothing.
        vm.prank(initialAdmin);
        authorizer.grantRole(DEPOSIT, from);
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CertificationExpired.selector, from, address(0)));
        authorizer.authorize(user, TRANSFER_RECEIPT, data);

        vm.prank(initialAdmin);
        authorizer.grantRole(WITHDRAW, from);
        vm.stopPrank();

        authorizer.authorize(user, TRANSFER_RECEIPT, data);
    }
}
