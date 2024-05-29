pragma solidity 0.8.17;

import {VaultConfig} from "../../contracts/vault/receipt/ReceiptVault.sol";
import {Test, Vm} from "forge-std/Test.sol";
import {
    OffchainAssetReceiptVault,
    OffchainAssetVaultConfig,
    OffchainAssetReceiptVaultConfig,
    ZeroAdmin,
    NonZeroAsset
} from "../../contracts/vault/offchainAsset/OffchainAssetReceiptVault.sol";
import {ReceiptFactory} from "../../contracts/vault/receipt/ReceiptFactory.sol";
import {ReceiptVaultFactoryConfig} from "../../contracts/vault/receipt/ReceiptVaultFactory.sol";
import {OffchainAssetReceiptVaultFactory} from
    "../../contracts/vault/offchainAsset/OffchainAssetReceiptVaultFactory.sol";
import {IReceiptV1} from "../../contracts/vault/receipt/IReceiptV1.sol";

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

    /// Test that admin is not address zero
    function testZeroAdmin(string memory assetName, string memory assetSymbol) public {
        vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: address(0), vaultConfig: vaultConfig});

        vm.expectRevert(abi.encodeWithSelector(ZeroAdmin.selector));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    /// Test that asset is address zero
    function testNonZeroAsset(address asset, string memory assetName, string memory assetSymbol) public {
        vm.assume(asset != address(0));
        vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vm.expectRevert(abi.encodeWithSelector(NonZeroAsset.selector));
        vault = factory.createChildTyped(offchainAssetVaultConfig);
    }

    /// Test that offchainAssetReceiptVault constructs well
    function testConstruction(string memory assetName, string memory assetSymbol) public {
        address asset = address(0);

        vaultConfig = VaultConfig({asset: asset, name: assetName, symbol: assetSymbol});
        offchainAssetVaultConfig = OffchainAssetVaultConfig({admin: alice, vaultConfig: vaultConfig});

        vault = factory.createChildTyped(offchainAssetVaultConfig);

        assert(address(vault.asset()) == asset);
        assert(keccak256(bytes(vault.name())) == keccak256(bytes(assetName)));
        assert(keccak256(bytes(vault.symbol())) == keccak256(bytes(assetSymbol)));
    }

    /// Test that vault is the owner of its receipt
    function testVaultIsReceiptOwner(string memory assetName, string memory assetSymbol) public {
        vaultConfig = VaultConfig({asset: address(0), name: assetName, symbol: assetSymbol});
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
        // Check sender
        assert(msgSender == address(factory));

        // Interact with the receipt contract
        address owner = receipt.owner();
        assert(owner == address(vault));
    }
}
