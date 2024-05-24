pragma solidity 0.8.17;

import "../../contracts/vault/receipt/ReceiptVault.sol";
import "../../contracts/vault/receipt/ReceiptFactory.sol";
import "../../contracts/vault/receipt/IReceiptV1.sol";

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
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vm.expectRevert(abi.encodeWithSignature("NonZeroAsset()"));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    function testConstruction() public {
        address asset = address(0);
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        vaultConfig = VaultConfig(asset, assetName, assetSymbol);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vault = factory.createChildTyped(offchainAssetVaultConfig);

        assert(address(vault.asset()) == asset);
        assert(keccak256(abi.encodePacked(vault.name())) == keccak256(abi.encodePacked(assetName)));
        assert(keccak256(abi.encodePacked(vault.symbol())) == keccak256(abi.encodePacked(assetSymbol)));
    }

    function testVaultIsReceiptOwner() public {
        address asset = address(0);
        string memory assetName = "Asset Name";
        string memory assetSymbol = "ASSET";

        vaultConfig = VaultConfig(asset, assetName, assetSymbol);
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        // Start recording logs
        vm.recordLogs();
        vault = factory.createChildTyped(offchainAssetVaultConfig);

        // Get the logs
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Find the OffchainAssetReceiptVaultInitialized event log
        address receiptAddress = address(0);
        address msgSender = address(0);
        for (uint256 i = 0; i < logs.length; i++) {
            if (
                logs[i].topics[0]
                    == keccak256(
                        "OffchainAssetReceiptVaultInitialized(address,(address,(address,(address,string,string))))"
                    )
            ) {
                // Decode the event data
                (address sender, OffchainAssetReceiptVaultConfig memory config) =
                    abi.decode(logs[i].data, (address, OffchainAssetReceiptVaultConfig));
                receiptAddress = config.receiptVaultConfig.receipt;
                msgSender = sender;
                break;
            }
        }
        // Create an instance of the Receipt contract
        IReceiptV1 receipt = IReceiptV1(receiptAddress);

        // Check that the receipt address is not zero
        assert(receiptAddress != address(0));
        //Check sender
        assert(msgSender == address(factory));

        // Interact with the receipt contract
        address owner = receipt.owner();
        assert(owner == address(vault));
    }
}
