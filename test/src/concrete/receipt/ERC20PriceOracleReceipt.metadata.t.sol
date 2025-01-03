// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {TestReceiptManager} from "test/concrete/TestReceiptManager.sol";
import {ERC20PriceOracleReceipt} from "src/concrete/receipt/ERC20PriceOracleReceipt.sol";
import {LibFixedPointDecimalFormat} from "rain.math.fixedpoint/lib/format/LibFixedPointDecimalFormat.sol";
import {
    LibFixedPointDecimalArithmeticOpenZeppelin,
    Math
} from "rain.math.fixedpoint/lib/LibFixedPointDecimalArithmeticOpenZeppelin.sol";
import {FIXED_POINT_ONE} from "rain.math.fixedpoint/lib/FixedPointDecimalConstants.sol";
import {ZeroReceiptId} from "src/error/ErrReceipt.sol";
import {LibConformString} from "rain.string/lib/mut/LibConformString.sol";
import {CMASK_QUOTATION_MARK, CMASK_PRINTABLE, CMASK_BACKSLASH} from "rain.string/lib/parse/LibParseCMask.sol";

/// This contract is used to test the metadata of the `Receipt` contract.
/// As all the overridden functions are internal, we need to create a new
/// contract that inherits from `Receipt` and exposes these functions; we can't
/// just mock `Receipt`.
contract MutableMetadataReceipt is ERC20PriceOracleReceipt {
    string internal sVaultShareSymbol;
    string internal sVaultAssetSymbol;
    string internal sReceiptSVGURI;
    string internal sReferenceAssetSymbol;
    string internal sRedeemURL;
    string internal sBrandName;

    function setVaultShareSymbol(string memory vaultShareSymbol) external {
        sVaultShareSymbol = vaultShareSymbol;
    }

    function setVaultAssetSymbol(string memory vaultAssetSymbol) external {
        sVaultAssetSymbol = vaultAssetSymbol;
    }

    function setReceiptSVGURI(string memory receiptSVGURI) external {
        sReceiptSVGURI = receiptSVGURI;
    }

    function setReferenceAssetSymbol(string memory referenceAssetSymbol) external {
        sReferenceAssetSymbol = referenceAssetSymbol;
    }

    function setRedeemURL(string memory redeemURL) external {
        sRedeemURL = redeemURL;
    }

    function setBrandName(string memory brandName) external {
        sBrandName = brandName;
    }

    function _vaultShareSymbol() internal view override returns (string memory) {
        return sVaultShareSymbol;
    }

    function _vaultAssetSymbol() internal view override returns (string memory) {
        return sVaultAssetSymbol;
    }

    function _receiptSVGURI() internal view override returns (string memory) {
        return sReceiptSVGURI;
    }

    function _referenceAssetSymbol() internal view override returns (string memory) {
        return sReferenceAssetSymbol;
    }

    function _redeemURL() internal view override returns (string memory) {
        return sRedeemURL;
    }

    function _brandName() internal view override returns (string memory) {
        return sBrandName;
    }
}

contract ERC20PriceOracleReceiptMetadataTest is ReceiptFactoryTest {
    function testReceiptURIZeroError() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iERC20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        vm.expectRevert(ZeroReceiptId.selector);
        receipt.uri(0);
    }

    function testReceiptURI(uint256 id) external {
        vm.assume(id != 0);

        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iERC20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        string memory uri = receipt.uri(id);

        Metadata memory metadataJson = decodeMetadataURI(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
        );
        assertEq(
            metadataJson.description,
            string.concat(
                "1 of these receipts can be burned alongside 1 TRM to redeem ", idInvFormatted, " of TRMAsset."
            )
        );

        assertEq(metadataJson.decimals, 18);
        assertEq(
            metadataJson.name,
            string.concat(
                "Receipt for lock at ", LibFixedPointDecimalFormat.fixedPointToDecimalString(id), " USD per TRMAsset."
            )
        );
    }

    function testReceiptName() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iERC20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        assertEq(receipt.name(), "TRM Receipt");
    }

    function testReceiptSymbol() external {
        // Deploy the Receipt contract
        TestReceiptManager testManager = new TestReceiptManager();
        ERC20PriceOracleReceipt receipt = ERC20PriceOracleReceipt(
            iFactory.clone(address(iERC20PriceOracleReceiptImplementation), abi.encode(address(testManager)))
        );

        assertEq(receipt.symbol(), "TRM RCPT");
    }

    function testOverriddenMetadata(
        uint256 id,
        string memory vaultShareSymbol,
        string memory vaultAssetSymbol,
        string memory redeemURL,
        string memory brandName,
        string memory referenceAssetSymbol
    ) external {
        vm.assume(id != 0);
        MutableMetadataReceipt receipt = new MutableMetadataReceipt();

        {
            uint256 mask = CMASK_PRINTABLE & ~(CMASK_QUOTATION_MARK | CMASK_BACKSLASH);

            LibConformString.conformStringToMask(vaultShareSymbol, mask, 0x100);
            LibConformString.conformStringToMask(vaultAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(redeemURL, mask, 0x100);
            LibConformString.conformStringToMask(brandName, mask, 0x100);
            LibConformString.conformStringToMask(referenceAssetSymbol, mask, 0x100);

            receipt.setVaultShareSymbol(vaultShareSymbol);
            receipt.setVaultAssetSymbol(vaultAssetSymbol);
            receipt.setRedeemURL(redeemURL);
            receipt.setBrandName(brandName);
            receipt.setReferenceAssetSymbol(referenceAssetSymbol);
        }

        string memory uri = receipt.uri(id);
        Metadata memory metadata = decodeMetadataURI(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
        );

        string memory redeemURLPhrase = bytes(redeemURL).length > 0 ? string.concat(" Redeem at ", redeemURL, ".") : "";
        string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";

        assertEq(metadata.decimals, 18);
        assertEq(
            metadata.description,
            string.concat(
                "1 of these receipts can be burned alongside 1 ",
                vaultShareSymbol,
                " to redeem ",
                idInvFormatted,
                " of ",
                vaultAssetSymbol,
                ".",
                redeemURLPhrase
            )
        );
        assertEq(
            metadata.name,
            string.concat(
                "Receipt for ",
                brandNamePhrase,
                "lock at ",
                LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
                " ",
                referenceAssetSymbol,
                " per ",
                vaultAssetSymbol,
                "."
            )
        );
    }

    function testOverriddenMetadataWithImage(
        uint256 id,
        string memory vaultShareSymbol,
        string memory vaultAssetSymbol,
        string memory redeemURL,
        string memory brandName,
        string memory referenceAssetSymbol,
        string memory receiptSVGURI
    ) external {
        vm.assume(bytes(receiptSVGURI).length > 0);
        vm.assume(id != 0);
        MutableMetadataReceipt receipt = new MutableMetadataReceipt();

        {
            uint256 mask = CMASK_PRINTABLE & ~(CMASK_QUOTATION_MARK | CMASK_BACKSLASH);

            LibConformString.conformStringToMask(vaultShareSymbol, mask, 0x100);
            LibConformString.conformStringToMask(vaultAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(redeemURL, mask, 0x100);
            LibConformString.conformStringToMask(brandName, mask, 0x100);
            LibConformString.conformStringToMask(referenceAssetSymbol, mask, 0x100);
            LibConformString.conformStringToMask(receiptSVGURI, mask, 0x100);

            receipt.setVaultShareSymbol(vaultShareSymbol);
            receipt.setVaultAssetSymbol(vaultAssetSymbol);
            receipt.setRedeemURL(redeemURL);
            receipt.setBrandName(brandName);
            receipt.setReferenceAssetSymbol(referenceAssetSymbol);
            receipt.setReceiptSVGURI(receiptSVGURI);
        }

        string memory uri = receipt.uri(id);
        MetadataWithImage memory metadata = decodeMetadataURIWithImage(uri);

        string memory idInvFormatted = LibFixedPointDecimalFormat.fixedPointToDecimalString(
            LibFixedPointDecimalArithmeticOpenZeppelin.fixedPointDiv(FIXED_POINT_ONE, id, Math.Rounding.Down)
        );

        assertEq(metadata.decimals, 18);

        {
            string memory redeemURLPhrase =
                bytes(redeemURL).length > 0 ? string.concat(" Redeem at ", redeemURL, ".") : "";
            assertEq(
                metadata.description,
                string.concat(
                    "1 of these receipts can be burned alongside 1 ",
                    vaultShareSymbol,
                    " to redeem ",
                    idInvFormatted,
                    " of ",
                    vaultAssetSymbol,
                    ".",
                    redeemURLPhrase
                )
            );
        }

        {
            string memory brandNamePhrase = bytes(brandName).length > 0 ? string.concat(brandName, " ") : "";
            assertEq(
                metadata.name,
                string.concat(
                    "Receipt for ",
                    brandNamePhrase,
                    "lock at ",
                    LibFixedPointDecimalFormat.fixedPointToDecimalString(id),
                    " ",
                    referenceAssetSymbol,
                    " per ",
                    vaultAssetSymbol,
                    "."
                )
            );
        }

        assertEq(metadata.image, receiptSVGURI);
    }
}
