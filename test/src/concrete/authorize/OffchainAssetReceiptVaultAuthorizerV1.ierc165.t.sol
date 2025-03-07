// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {OffchainAssetReceiptVaultAuthorizerV1} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAuthorizeV1} from "src/interface/IAuthorizeV1.sol";
import {ICloneableV2} from "rain.factory/interface/ICloneableV2.sol";
import {IAccessControlUpgradeable as IAccessControl} from
    "openzeppelin-contracts-upgradeable/contracts/access/IAccessControlUpgradeable.sol";

contract OffchainAssetReceiptVaultAuthorizerV1Test is Test {
    function testOffchainAssetReceiptVaultAuthorizerV1IERC165(bytes4 badInterfaceId) external {
        vm.assume(badInterfaceId != type(IERC165).interfaceId);
        vm.assume(badInterfaceId != type(ICloneableV2).interfaceId);
        vm.assume(badInterfaceId != type(IAuthorizeV1).interfaceId);
        vm.assume(badInterfaceId != type(IAccessControl).interfaceId);

        OffchainAssetReceiptVaultAuthorizerV1 authorizer = new OffchainAssetReceiptVaultAuthorizerV1();
        assertTrue(authorizer.supportsInterface(type(IERC165).interfaceId));
        assertTrue(authorizer.supportsInterface(type(ICloneableV2).interfaceId));
        assertTrue(authorizer.supportsInterface(type(IAuthorizeV1).interfaceId));
        assertTrue(authorizer.supportsInterface(type(IAccessControl).interfaceId));

        assertFalse(authorizer.supportsInterface(badInterfaceId));
    }
}
