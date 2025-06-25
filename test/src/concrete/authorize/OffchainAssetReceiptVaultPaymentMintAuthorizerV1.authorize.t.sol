// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config,
    ZeroReceiptVault,
    ZeroInitialOwner,
    ZeroPaymentToken,
    ZeroMaxSharesSupply,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {IERC20MetadataUpgradeable as IERC20Metadata} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1IERC165Test is Test {
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
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, owner, paymentToken, paymentTokenDecimals, maxSharesSupply);

        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, user, permission, data));
        vm.prank(caller);
        authorizer.authorize(user, permission, data);
    }
}
