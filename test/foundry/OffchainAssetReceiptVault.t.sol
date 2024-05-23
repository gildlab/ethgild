pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";

import "forge-std/Test.sol";

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
    }

    function testZeroAdmin() public {
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        vaultConfig = VaultConfig(address(0), assetName, assetSymbol);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: address(0), vaultConfig: vaultConfig});

        vm.expectRevert(abi.encodeWithSignature("ZeroAdmin()"));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    function testNonZeroAsset() public {
        address asset = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        vaultConfig = VaultConfig(asset, assetName, assetSymbol);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: address(0), vaultConfig: vaultConfig});

        vm.expectRevert(abi.encodeWithSignature("NonZeroAsset()"));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }
}
