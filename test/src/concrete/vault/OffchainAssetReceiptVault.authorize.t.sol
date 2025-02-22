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
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);
        (bob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        address authorizor = address(vault.authorizor());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizor.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizorImplementation));
    }

    /// Test that the owner can change the authorizor.
    function testChangeAuthorizor(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol
    ) external {
        (address alice, address bob) =
            LibUniqueAddressesGenerator.generateUniqueAddresses(vm, SECP256K1_ORDER, fuzzedKeyAlice, fuzzedKeyBob);

        OffchainAssetReceiptVault vault = createVault(alice, assetName, assetSymbol);

        address authorizor = address(vault.authorizor());
        (bool isProxy, address implementation) = LibExtrospectERC1167Proxy.isERC1167Proxy(authorizor.code);
        assertTrue(isProxy);
        assertEq(implementation, address(iAuthorizorImplementation));

        AlwaysAuthorize alwaysAuthorize = new AlwaysAuthorize();

        vm.prank(alice);
        vault.setAuthorizor(alwaysAuthorize);

        authorizor = address(vault.authorizor());
        assertEq(authorizor, address(alwaysAuthorize));

        AlwaysAuthorize alwaysAuthorize2 = new AlwaysAuthorize();

        // Bob cannot set the authorizor.
        vm.prank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        vault.setAuthorizor(alwaysAuthorize2);
    }
}
