pragma solidity =0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";
import "../../contracts/test/CreateOffchainAssetReceiptVaultFactory.sol";

import "forge-std/Test.sol";

import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";

contract OffChainAssetReceiptVaultFactoryTest is Test, CreateOffchainAssetReceiptVaultFactory {
    OffchainAssetVaultConfig offchainAssetVaultConfig;
    VaultConfig vaultConfig;
    OffchainAssetReceiptVault vault;
    address alice;

    function setUp() public {
        createOffchainAssetReceiptVaultFactory();
    }

    function testOffchainAssetReceiptVaultFactoryConstuction() public view {
        assert(address(factory) != address(0));
    }

    function testCreateChild() public {
        // Get the first signer address
        alice = vm.addr(1);

        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        // VaultConfig to create child contract
        vaultConfig = VaultConfig(address(0), assetName, assetSymbol);

        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vault = factory.createChildTyped(offchainAssetVaultConfig);
        assert(address(vault) != address(0));
        assert(keccak256(abi.encodePacked(vault.name())) == keccak256(abi.encodePacked(assetName)));
        assert(keccak256(abi.encodePacked(vault.symbol())) == keccak256(abi.encodePacked(assetSymbol)));
    }
}
