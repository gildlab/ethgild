// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";

import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config,
    ZeroReceiptVault,
    ZeroInitialOwner,
    ZeroPaymentToken,
    ZeroMaxSharesSupply,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {
    CERTIFY,
    CONFISCATE_SHARES,
    CONFISCATE_RECEIPT
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165Test is OffchainAssetReceiptVaultAuthorizerV1Test {
    function newAuthorizer(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply
    ) internal returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1) {
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
        vm.mockCall(
            paymentToken, abi.encodeWithSelector(IERC20Metadata.decimals.selector), abi.encode(paymentTokenDecimals)
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1UnauthorizedCaller(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        bytes32 permission,
        bytes calldata data,
        address caller
    ) external {
        vm.assume(receiptVault != address(0));
        vm.assume(owner != address(0));
        vm.assume(paymentToken != address(0));
        vm.assume(maxSharesSupply > 0);
        vm.assume(caller != receiptVault);
        vm.assume(uint160(caller) > type(uint160).max / 2);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);

        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        vm.prank(caller);
        authorizer.authorize(user, permission, data);
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1AuthorizeUnauthorized(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address sender,
        address user,
        bytes32 permission,
        bytes memory data
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        vm.assume(uint160(sender) > type(uint160).max / 2);
        checkDefaultOffchainAssetReceiptVaultAuthorizerV1AuthorizeUnauthorized(
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply),
            sender,
            user,
            permission,
            data
        );
    }

    function testOffchainAssetReceiptVaultPaymentMintAuthorizerV1RolesAuthorized(
        address receiptVault,
        address owner,
        address paymentToken,
        uint8 paymentTokenDecimals,
        uint256 maxSharesSupply,
        address user,
        bytes memory data
    ) external {
        vm.assume(owner != address(0));
        vm.assume(receiptVault != address(0));
        vm.assume(uint160(paymentToken) > type(uint160).max / 2);
        vm.assume(maxSharesSupply > 0);
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);
        bytes32[] memory roles = new bytes32[](3);
        roles[0] = CERTIFY;
        roles[1] = CONFISCATE_SHARES;
        roles[2] = CONFISCATE_RECEIPT;
        checkRolesAuthorized(authorizer, owner, receiptVault, user, data, roles);
    }
}
