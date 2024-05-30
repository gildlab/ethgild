// SPDX-License-Identifier: CAL
pragma solidity =0.8.17;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {CreateOffchainAssetReceiptVaultFactory} from "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";
import {Test, Vm} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";

import {TestErc20} from "../../contracts/test/TestErc20.sol";
import {ReadWriteTier} from "../../contracts/test/ReadWriteTier.sol";
import {Utils} from "./Utils.sol";

contract RolesTest is Test, CreateOffchainAssetReceiptVaultFactory {
    //shareRatio 1
    uint256 shareRatio = 1e18;
    address alice;
    OffchainAssetReceiptVault vault;

    function testGrantAdminRoles(uint256 fuzzedKeyAlice, string memory assetName, string memory assetSymbol) external {
        // Ensure the fuzzed key is within the valid range for secp256k1
        fuzzedKeyAlice = bound(fuzzedKeyAlice, 1, SECP256K1_ORDER - 1);
        alice = vm.addr(fuzzedKeyAlice);

        Utils utils = new Utils();
        vault = utils.createVault(alice, assetName, assetSymbol);

        bytes32 DEPOSITOR_ADMIN = vault.DEPOSITOR_ADMIN();
        bytes32 WITHDRAWER_ADMIN = vault.WITHDRAWER_ADMIN();
        bytes32 CERTIFIER_ADMIN = vault.CERTIFIER_ADMIN();
        bytes32 HANDLER_ADMIN = vault.HANDLER_ADMIN();
        bytes32 ERC20TIERER_ADMIN = vault.ERC20TIERER_ADMIN();
        bytes32 ERC1155TIERER_ADMIN = vault.ERC1155TIERER_ADMIN();
        bytes32 ERC20SNAPSHOTTER_ADMIN = vault.ERC20SNAPSHOTTER_ADMIN();
        bytes32 CONFISCATOR_ADMIN = vault.CONFISCATOR_ADMIN();

        bool DEPOSITOR_ADMIN_Granted = vault.hasRole(DEPOSITOR_ADMIN, alice);
        bool WITHDRAWER_ADMIN_Granted = vault.hasRole(WITHDRAWER_ADMIN, alice);
        bool CERTIFIER_ADMIN_Granted = vault.hasRole(CERTIFIER_ADMIN, alice);
        bool HANDLER_ADMIN_Granted = vault.hasRole(HANDLER_ADMIN, alice);
        bool ERC20TIERER_ADMIN_Granted = vault.hasRole(ERC20TIERER_ADMIN, alice);
        bool ERC1155TIERER_ADMIN_Granted = vault.hasRole(ERC1155TIERER_ADMIN, alice);
        bool ERC20SNAPSHOTTER_ADMIN_Granted = vault.hasRole(ERC20SNAPSHOTTER_ADMIN, alice);
        bool CONFISCATOR_ADMIN_Granted = vault.hasRole(CONFISCATOR_ADMIN, alice);

        assertTrue(DEPOSITOR_ADMIN_Granted);
        assertTrue(WITHDRAWER_ADMIN_Granted);
        assertTrue(CERTIFIER_ADMIN_Granted);
        assertTrue(HANDLER_ADMIN_Granted);
        assertTrue(ERC20TIERER_ADMIN_Granted);
        assertTrue(ERC1155TIERER_ADMIN_Granted);
        assertTrue(ERC20SNAPSHOTTER_ADMIN_Granted);
        assertTrue(CONFISCATOR_ADMIN_Granted);
    }

    function testDepositWithoutDepositorRole(
        uint256 fuzzedKeyAlice,
        string memory assetName,
        string memory assetSymbol,
        uint256 fuzzedKeyBob,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) external {
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

        vm.expectRevert(abi.encodeWithSignature("MinShareRatio(uint256,uint256)", shareRatio, 0));
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    //    function testSetERC20TierWithoutRole(bytes memory data, uint8 minTier, uint256[] memory context) public {
    //        // Prank as Alice for the transaction
    //        vm.startPrank(alice);
    //        //New testErc20 contract
    //        TierV2TestContract = new ReadWriteTier();
    //
    //        string memory errorMessage = string(
    //            abi.encodePacked(
    //                "AccessControl: account ",
    //                StringsUpgradeable.toHexString(alice),
    //                " is missing role ",
    //                vm.toString(vault.ERC20TIERER())
    //            )
    //        );
    //        vm.expectRevert(bytes(errorMessage));
    //
    //        //set Tier
    //        vault.setERC20Tier(address(TierV2TestContract), minTier, context, data);
    //    }
    //
    //    function testSetERC1155TierWithoutRole(bytes memory data, uint8 minTier, uint256[] memory context) public {
    //        // Prank as Alice for the transaction
    //        vm.startPrank(alice);
    //        //New testErc20 contract
    //        TierV2TestContract = new ReadWriteTier();
    //
    //        string memory errorMessage = string(
    //            abi.encodePacked(
    //                "AccessControl: account ",
    //                StringsUpgradeable.toHexString(alice),
    //                " is missing role ",
    //                vm.toString(vault.ERC1155TIERER())
    //            )
    //        );
    //        vm.expectRevert(bytes(errorMessage));
    //
    //        //set Tier
    //        vault.setERC1155Tier(address(TierV2TestContract), minTier, context, data);
    //    }
    //
    //    function testSnapshotWithoutRole(bytes memory data) public {
    //        // Prank as Alice for the transaction
    //        vm.startPrank(alice);
    //        string memory errorMessage = string(
    //            abi.encodePacked(
    //                "AccessControl: account ",
    //                StringsUpgradeable.toHexString(alice),
    //                " is missing role ",
    //                vm.toString(vault.ERC20SNAPSHOTTER())
    //            )
    //        );
    //        vm.expectRevert(bytes(errorMessage));
    //
    //        //snapshot
    //        vault.snapshot(data);
    //    }
    //
    //    function testCertifyWithoutRole(uint256 certifyUntil, bytes memory data) public {
    //        // Prank as Alice for the transaction
    //        vm.startPrank(alice);
    //        bool forceUntil = false;
    //
    //        string memory errorMessage = string(
    //            abi.encodePacked(
    //                "AccessControl: account ",
    //                StringsUpgradeable.toHexString(alice),
    //                " is missing role ",
    //                vm.toString(vault.CERTIFIER())
    //            )
    //        );
    //        vm.expectRevert(bytes(errorMessage));
    //
    //        // Call the certify function
    //        vault.certify(certifyUntil, block.number, forceUntil, data);
    //
    //        vm.stopPrank();
    //    }
    //
    //    function testConfiscateWithoutRole(bytes memory data) public {
    //        // Prank as Alice for the transaction
    //        vm.startPrank(alice);
    //        string memory errorMessage = string(
    //            abi.encodePacked(
    //                "AccessControl: account ",
    //                StringsUpgradeable.toHexString(alice),
    //                " is missing role ",
    //                vm.toString(vault.CONFISCATOR())
    //            )
    //        );
    //        vm.expectRevert(bytes(errorMessage));
    //
    //        // Call the confiscateShares function
    //        vault.confiscateShares(alice, data);
    //
    //        vm.stopPrank();
}
