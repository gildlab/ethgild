pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";
import "../../contracts/test/TestErc20.sol";

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultTest is Test {
    OffchainAssetReceiptVaultFactory factory;
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault implementation;
    ReceiptFactory receiptFactory;
    ReceiptVaultFactoryConfig factoryConfig;
    OffchainAssetReceiptVault vault;
    TestErc20 testErc20Contract;
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

    function testGrantAdminRoles() public view {
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

        assert(DEPOSITOR_ADMIN_Granted == true);
        assert(WITHDRAWER_ADMIN_Granted == true);
        assert(CERTIFIER_ADMIN_Granted == true);
        assert(HANDLER_ADMIN_Granted == true);
        assert(ERC20TIERER_ADMIN_Granted == true);
        assert(ERC1155TIERER_ADMIN_Granted == true);
        assert(ERC20SNAPSHOTTER_ADMIN_Granted == true);
        assert(CONFISCATOR_ADMIN_Granted == true);
    }

    function testDepositWithoutDepositorRole() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Get the second signer address
        address bob = vm.addr(2);
        uint256 aliceAssets = 10;
        bytes memory receiptInformation = "";

        vm.expectRevert(abi.encodeWithSignature("MinShareRatio(uint256,uint256)", shareRatio, 0));
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
        vm.stopPrank();
    }

    function testWithdrawWithoutDepositorRole() public {
        // Prank as Alice for the transaction
        vm.startPrank(alice);

        // Get the second signer address
        address bob = vm.addr(2);

        uint256 aliceAssets = 10;
        bytes memory receiptInformation = "";

        //New testErc20 contract
        testErc20Contract = new TestErc20();
        testErc20Contract.transfer(alice, aliceAssets);
        testErc20Contract.increaseAllowance(address(vault), aliceAssets);

        // Grant CERTIFIER role to Alice
        vault.grantRole(vault.CERTIFIER(), alice);

        // Get the current block number
        uint256 blockNum = block.number;

        // Set up expected parameters
        uint256 certifyUntil = block.timestamp + 1000;
        bool forceUntil = false;
        bytes memory data = abi.encodePacked("Certification data");

        // Call the certify function
        vault.certify(certifyUntil, blockNum, forceUntil, data);

        vault.grantRole(vault.DEPOSITOR(), alice);
        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);

        vault.grantRole(vault.WITHDRAWER(), bob);
        vault.redeem(1, bob, bob, shareRatio, receiptInformation);

        vm.stopPrank();
    }
}