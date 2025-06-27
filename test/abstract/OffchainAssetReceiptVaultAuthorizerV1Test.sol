// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";

import {IAuthorizeV1, Unauthorized} from "src/interface/IAuthorizeV1.sol";
import {TRANSFER_SHARES, TRANSFER_RECEIPT} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

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
}
