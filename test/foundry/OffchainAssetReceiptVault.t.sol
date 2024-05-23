pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";

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
    address alice;

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


    }

    function testOffchainAssetReceiptVaultZeroAdmin() public {
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: address (0), vaultConfig: vaultConfig});
        vm.expectRevert(abi.encodeWithSignature("ZeroAdmin()"));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

//    function testDepositWithoutDepositorRole() public {
//        // Prank as Alice for the transaction
//        vm.startPrank(alice);
//
//        // Get the second signer address
//        address bob = vm.addr(2);
//        uint256 aliceAssets = 10;
//        bytes memory receiptInformation = "";
//
//        vm.expectRevert(abi.encodeWithSignature("MinShareRatio(uint256,uint256)", shareRatio, 0));
//        vault.deposit(aliceAssets, bob, shareRatio, receiptInformation);
//        vm.stopPrank();
//    }


}