// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    ZeroReceiptVault,
    ZeroInitialOwner,
    ZeroPaymentToken,
    ZeroMaxSharesSupply
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {
    WITHDRAW,
    DEPOSIT,
    CONFISCATE_RECEIPT,
    CONFISCATE_SHARES,
    CERTIFY
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    WITHDRAW_ADMIN,
    DEPOSIT_ADMIN,
    CONFISCATE_RECEIPT_ADMIN,
    CONFISCATE_SHARES_ADMIN,
    CERTIFY_ADMIN
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1ConstructTest is Test {
    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1Construct() external {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();

        vm.expectRevert("Initializable: contract is already initialized");
        authorizer.initialize(
            abi.encode(
                OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                    receiptVault: address(0),
                    owner: address(0),
                    paymentToken: address(0),
                    maxSharesSupply: 0
                })
            )
        );
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1ZeroReceiptVault() external {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: address(0),
                owner: address(0),
                paymentToken: address(0),
                maxSharesSupply: 0
            })
        );
        vm.expectRevert(ZeroReceiptVault.selector);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1ZeroInitialOwner(address receiptVault) external {
        vm.assume(receiptVault != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                owner: address(0),
                paymentToken: address(0),
                maxSharesSupply: 0
            })
        );
        vm.expectRevert(ZeroInitialOwner.selector);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1ZeroPaymentToken(address receiptVault, address owner)
        external
    {
        vm.assume(receiptVault != address(0));
        vm.assume(owner != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                owner: owner,
                paymentToken: address(0),
                maxSharesSupply: 0
            })
        );
        vm.expectRevert(ZeroPaymentToken.selector);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1ZeroMaxSharesSupply(
        address receiptVault,
        address owner,
        address paymentToken
    ) external {
        vm.assume(receiptVault != address(0));
        vm.assume(owner != address(0));
        vm.assume(paymentToken != address(0));
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: 0
            })
        );
        vm.expectRevert(ZeroMaxSharesSupply.selector);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1Initialize(
        address receiptVault,
        address owner,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        bytes32 badRole
    ) external {
        address paymentToken = address(0x1234567890123456789012345678901234567890);
        vm.assume(receiptVault != address(0));
        vm.assume(owner != address(0));
        vm.assume(paymentToken != address(0));
        vm.assume(maxSharesSupply > 0);
        vm.assume(badRole != CERTIFY_ADMIN);
        vm.assume(badRole != CONFISCATE_SHARES_ADMIN);
        vm.assume(badRole != CONFISCATE_RECEIPT_ADMIN);
        vm.assume(badRole != DEPOSIT_ADMIN);
        vm.assume(badRole != WITHDRAW_ADMIN);
        vm.assume(badRole != CERTIFY);
        vm.assume(badRole != CONFISCATE_SHARES);
        vm.assume(badRole != CONFISCATE_RECEIPT);
        vm.assume(badRole != DEPOSIT);
        vm.assume(badRole != WITHDRAW);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();

        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: maxSharesSupply
            })
        );
        vm.etch(paymentToken, hex"FF");
        vm.mockCall(
            paymentToken, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(paymentTokenDecimals)
        );

        vm.expectEmit(true, true, false, true);
        emit OffchainAssetReceiptVaultPaymentMintAuthorizerV1.Initialized(
            receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply
        );
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
        assertEq(authorizer.receiptVault(), receiptVault);
        assertEq(authorizer.paymentToken(), paymentToken);
        assertEq(authorizer.maxSharesSupply(), maxSharesSupply);
        assertEq(authorizer.paymentTokenDecimals(), IERC20Metadata(paymentToken).decimals());
        assertEq(authorizer.owner(), owner);
        assertTrue(authorizer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(authorizer.supportsInterface(type(ICloneableV2).interfaceId));
        assertTrue(authorizer.supportsInterface(type(IAuthorizeV1).interfaceId));

        vm.assertTrue(authorizer.hasRole(CERTIFY_ADMIN, owner));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_SHARES_ADMIN, owner));
        vm.assertTrue(authorizer.hasRole(CONFISCATE_RECEIPT_ADMIN, owner));
        vm.assertTrue(authorizer.hasRole(DEPOSIT_ADMIN, owner));
        vm.assertTrue(authorizer.hasRole(WITHDRAW_ADMIN, owner));

        vm.assertTrue(!authorizer.hasRole(CERTIFY, owner));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_SHARES, owner));
        vm.assertTrue(!authorizer.hasRole(CONFISCATE_RECEIPT, owner));
        vm.assertTrue(!authorizer.hasRole(DEPOSIT, owner));
        vm.assertTrue(!authorizer.hasRole(WITHDRAW, owner));
        vm.assertTrue(!authorizer.hasRole(badRole, owner));
    }
}
