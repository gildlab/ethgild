// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std/Test.sol";

import {
    OffchainAssetReceiptVaultAuthorizerV1,
    OffchainAssetReceiptVaultAuthorizerV1Config
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";

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
}
