// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {VaultConfig, MinShareRatio} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {StringsUpgradeable} from "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";
import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {ReadWriteTier} from "../../contracts/test/ReadWriteTier.sol";
import {Utils} from "./Utils.sol";

contract RolesTest is Test, CreateOffchainAssetReceiptVaultFactory {
    address alice;
    OffchainAssetReceiptVault vault;

    /// Test to checks Admin roles granted
    function testGrantAdminRoles(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);

        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        bytes32 depositorAdmin = vault.DEPOSITOR_ADMIN();
        bytes32 withdrawerAdmin = vault.WITHDRAWER_ADMIN();
        bytes32 certifierAdmin = vault.CERTIFIER_ADMIN();
        bytes32 handlerAdmin = vault.HANDLER_ADMIN();
        bytes32 erc20TiererAdmin = vault.ERC20TIERER_ADMIN();
        bytes32 erc1155TiererAdmin = vault.ERC1155TIERER_ADMIN();
        bytes32 erc20SnapshotterAdmin = vault.ERC20SNAPSHOTTER_ADMIN();
        bytes32 confiscatorAdmin = vault.CONFISCATOR_ADMIN();

        bool depositorAdminGranted = vault.hasRole(depositorAdmin, alice);
        bool withdrawerAdminGranted = vault.hasRole(withdrawerAdmin, alice);
        bool certifierAdminGranted = vault.hasRole(certifierAdmin, alice);
        bool handlerAdminGranted = vault.hasRole(handlerAdmin, alice);
        bool erc20TiererAdminGranted = vault.hasRole(erc20TiererAdmin, alice);
        bool erc1155TiererAdminGranted = vault.hasRole(erc1155TiererAdmin, alice);
        bool erc20SnapshotterAdminGranted = vault.hasRole(erc20SnapshotterAdmin, alice);
        bool confiscatorAdminGranted = vault.hasRole(confiscatorAdmin, alice);

        assertTrue(depositorAdminGranted);
        assertTrue(withdrawerAdminGranted);
        assertTrue(certifierAdminGranted);
        assertTrue(handlerAdminGranted);
        assertTrue(erc20TiererAdminGranted);
        assertTrue(erc1155TiererAdminGranted);
        assertTrue(erc20SnapshotterAdminGranted);
        assertTrue(confiscatorAdminGranted);
    }

    /// Test to checks deposit without depositor role
    function testDepositWithoutDepositorRole(
        uint256 fuzzedKeyAlice,
        uint256 fuzzedKeyBob,
        string memory assetName,
        string memory assetSymbol,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
        // ShareRatio 1
        uint256 shareRatio = 1e18;
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        fuzzedKeyBob = bound(fuzzedKeyBob, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);
        address bob = vm.addr(fuzzedKeyBob);

        // Constrain the inputs to ensure they are not same
        vm.assume(alice != bob);

        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(MinShareRatio.selector, shareRatio, 0));
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    /// Test to checks SetERC20Tier without role
    function testSetERC20TierWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint8 minTier,
        uint256[] memory context
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        // New testErc20 contract
        ReadWriteTier TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC20TIERER())
            )
        );

        vm.expectRevert(bytes(errorMessage));

        // Set Tier
        vault.setERC20Tier(address(TierV2TestContract), minTier, context, data);
    }

    /// Test to checks setERC1155Tier without role
    function testSetERC1155TierWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data,
        uint8 minTier,
        uint256[] memory context
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);

        // Prank as Alice for the transaction
        vm.startPrank(alice);

        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        // New testErc20 contract
        ReadWriteTier TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC1155TIERER())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Set Tier
        vault.setERC1155Tier(address(TierV2TestContract), minTier, context, data);
    }

    /// Test to checks snapshott without role
    function testSnapshotWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC20SNAPSHOTTER())
            )
        );
        vm.expectRevert(bytes(errorMessage));
        // Snapshot
        vault.snapshot(data);
    }

    /// Test to checks Certify without role
    function testCertifyWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 certifyUntil,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        bool forceUntil = false;

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.CERTIFIER())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Call the certify function
        vault.certify(certifyUntil, block.number, forceUntil, data);

        vm.stopPrank();
    }

    /// Test to checks Confiscate without role
    function testConfiscateWithoutRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        bytes memory data
    ) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.CONFISCATOR())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        // Call the confiscateShares function
        vault.confiscateShares(alice, data);

        vm.stopPrank();
    }
}
