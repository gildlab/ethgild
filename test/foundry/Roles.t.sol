pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";
import "../../contracts/test/ReadWriteTier.sol";
import "../../contracts/test/TestErc20.sol";
import "../../lib/openzeppelin-contracts-upgradeable/contracts/utils/StringsUpgradeable.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract RolesTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    ReceiptFactory receiptFactory;
    ReceiptVaultFactoryConfig factoryConfig;
    OffchainAssetReceiptVault vault;
    TestErc20 testErc20Contract;
    ReadWriteTier TierV2TestContract;
    address alice;
    //shareRatio 1
    uint256 shareRatio = 1e18;

    function setUp() public {
        implementation = new OffchainAssetReceiptVault();
        receiptFactory = new ReceiptFactory();

        // Set up factory config
        factoryConfig = ReceiptVaultFactoryConfig({
            implementation: address(implementation),
            receiptFactory: address(receiptFactory)
        });

        // Create OffchainAssetReceiptVaultFactory contract
        factory = new OffchainAssetReceiptVaultFactory(factoryConfig);
        // Get the first signer address
        alice = vm.addr(1);

        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        // VaultConfig to create child contract
        vaultConfig = VaultConfig(address(0), assetName, assetSymbol);

        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    function testGrantAdminRoles() public {
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
        address fuzzAlice,
        address fuzzBob,
        uint256 aliceAssets,
        bytes memory receiptInformation
    ) public {
        // Constrain the inputs to ensure they are not the zero address
        vm.assume(fuzzAlice != address(0));
        vm.assume(fuzzBob != address(0));

        // Prank as Alice for the transaction
        vm.startPrank(fuzzAlice);

        vm.expectRevert(abi.encodeWithSignature("MinShareRatio(uint256,uint256)", shareRatio, 0));
        vault.deposit(aliceAssets, fuzzBob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    function testSetERC20TierWithoutRole(bytes memory data, uint8 minTier, uint256[] memory context) public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        //New testErc20 contract
        TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC20TIERER())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        //set Tier
        vault.setERC20Tier(address(TierV2TestContract), minTier, context, data);
    }

    function testSetERC1155TierWithoutRole(bytes memory data, uint8 minTier, uint256[] memory context) public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        //New testErc20 contract
        TierV2TestContract = new ReadWriteTier();

        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC1155TIERER())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        //set Tier
        vault.setERC1155Tier(address(TierV2TestContract), minTier, context, data);
    }

    function testSnapshotWithoutRole(bytes memory data) public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);
        string memory errorMessage = string(
            abi.encodePacked(
                "AccessControl: account ",
                StringsUpgradeable.toHexString(alice),
                " is missing role ",
                vm.toString(vault.ERC20SNAPSHOTTER())
            )
        );
        vm.expectRevert(bytes(errorMessage));

        //snapshot
        vault.snapshot(data);
    }

    function testCertifyWithoutRole(uint256 certifyUntil, bytes memory data) public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);
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

    function testConfiscateWithoutRole(bytes memory data) public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);
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
