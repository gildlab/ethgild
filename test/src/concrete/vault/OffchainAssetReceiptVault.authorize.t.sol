// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultTest, Vm} from "test/abstract/OffchainAssetReceiptVaultTest.sol";
import {LibOffchainAssetVaultCreator} from "test/lib/LibOffchainAssetVaultCreator.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {OffchainAssetReceiptVault, IAuthorizeV1} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {LibExtrospectERC1167Proxy} from "rain.extrospection/lib/LibExtrospectERC1167Proxy.sol";
import {IERC165Upgradeable as IERC165} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";

contract AlwaysAuthorize is IAuthorizeV1, IERC165 {
    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32, bytes memory) external pure override {}
}

contract OffchainAssetReceiptVaultAuthorizeTest is OffchainAssetReceiptVaultTest {
    /// Test that authorize contract is as initialized.
    function testAuthorizeContract(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        (bob);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        address authorizor = address(vault.authorizor());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizor.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizerImplementation));
    }

    /// Test that the owner can change the authorizor.
    function testChangeAuthorizer(
        uint256 aliceSeed,
        uint256 bobSeed,
        string memory shareName,
        string memory shareSymbol
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        OffchainAssetReceiptVault vault = createVault(alice, shareName, shareSymbol);

        address authorizor = address(vault.authorizor());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizor.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizerImplementation));

        AlwaysAuthorize alwaysAuthorize = new AlwaysAuthorize();

        vm.prank(alice);
        vault.setAuthorizer(alwaysAuthorize);

        authorizor = address(vault.authorizor());
        assertEq(authorizor, address(alwaysAuthorize));

        AlwaysAuthorize alwaysAuthorize2 = new AlwaysAuthorize();

        // Bob cannot set the authorizor.
        vm.prank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setAuthorizer(alwaysAuthorize2);
    }
}
