// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    PaymentTokenDecimalMismatch,
    MaxSharesSupplyExceeded,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config} from
    "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {DepositStateChange, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {Receipt as ReceiptContract} from "src/concrete/receipt/Receipt.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    ReceiptVaultConstructionConfigV2,
    OffchainAssetVaultConfigV2,
    VaultConfig
} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";
import {LibFixedPointDecimalScale, FLAG_ROUND_UP} from "rain.math.fixedpoint/lib/LibFixedPointDecimalScale.sol";
import {ICloneableFactoryV2} from "rain.factory/interface/ICloneableFactoryV2.sol";

import {TestErc20} from "test/concrete/TestErc20.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1DepositTest is OffchainAssetReceiptVaultAuthorizerV1Test {
    ICloneableFactoryV2 internal immutable I_FACTORY;
    ReceiptContract internal immutable I_RECEIPT_IMPLEMENTATION;
    OffchainAssetReceiptVault internal immutable I_IMPLEMENTATION;

    constructor() {
        I_FACTORY = new CloneFactory();
        I_RECEIPT_IMPLEMENTATION = new ReceiptContract();
        I_IMPLEMENTATION = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: I_FACTORY, receiptImplementation: I_RECEIPT_IMPLEMENTATION})
        );
    }

    function newAuthorizer(address receiptVault, address owner, address paymentToken, uint256 maxSharesSupply)
        internal
        returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1)
    {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();
        bytes memory initData = abi.encode(
            OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                receiptVault: receiptVault,
                verify: address(new VerifyAlwaysApproved()),
                owner: owner,
                paymentToken: paymentToken,
                maxSharesSupply: maxSharesSupply
            })
        );
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(factory.clone(address(implementation), initData));
    }

    function testMintSimpleRealReceiptVault(
        address alice,
        address bob,
        uint256 maxShares,
        uint256 totalSupply,
        uint256 firstShares
    ) external {
        vm.assume(uint160(alice) > type(uint160).max / 2 && uint160(bob) > type(uint160).max / 2 && alice != bob);

        vm.prank(bob);
        TestErc20 paymentToken = new TestErc20();

        maxShares = bound(maxShares, 2e18, 1e27);
        totalSupply = bound(totalSupply, 0, 1e18);
        firstShares = bound(firstShares, 1, maxShares - totalSupply - 1);
        uint256 paymentAmount = firstShares;

        OffchainAssetReceiptVault receiptVaultImplementation = new OffchainAssetReceiptVault(
            ReceiptVaultConstructionConfigV2({factory: new CloneFactory(), receiptImplementation: new ReceiptContract()})
        );
        OffchainAssetReceiptVault receiptVault = OffchainAssetReceiptVault(
            payable(
                (new CloneFactory()).clone(
                    address(receiptVaultImplementation),
                    abi.encode(
                        OffchainAssetVaultConfigV2({
                            initialAdmin: alice,
                            vaultConfig: VaultConfig({asset: address(0), name: "Test Vault", symbol: "TVLT"})
                        })
                    )
                )
            )
        );

        vm.mockCall(address(receiptVault), abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(address(receiptVault), alice, address(paymentToken), maxShares);
        vm.startPrank(alice);
        receiptVault.setAuthorizer(authorizer);
        authorizer.grantRole(CERTIFY, alice);
        receiptVault.certify(block.timestamp + 1, false, "");
        vm.stopPrank();

        assertEq(authorizer.owner(), alice, "Owner should be set to Alice");
        assertEq(1e27, paymentToken.balanceOf(bob), "Bob should have all the payment tokens initially");
        assertEq(0, paymentToken.balanceOf(alice), "Alice should have no tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        // Alice can't afford to deposit.
        vm.startPrank(alice);
        paymentToken.approve(address(authorizer), paymentAmount);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        receiptVault.mint(firstShares, alice, 0, hex"");
        vm.stopPrank();

        // Bob can afford to deposit.
        vm.startPrank(bob);
        paymentToken.approve(address(authorizer), paymentAmount);
        receiptVault.mint(firstShares, bob, 0, hex"");
        vm.stopPrank();

        assertEq(1e27 - paymentAmount, paymentToken.balanceOf(bob), "Bob should have reduced balance after deposit");
        assertEq(
            paymentAmount,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after deposit"
        );
        assertEq(0, paymentToken.balanceOf(alice), "Alice should still have no tokens after deposit");

        authorizer.sendPaymentToOwner();

        assertEq(
            1e27 - paymentAmount, paymentToken.balanceOf(bob), "Bob should still have reduced balance after payment"
        );
        assertEq(paymentAmount, paymentToken.balanceOf(alice), "Alice should have received payment after send");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens after send");
    }

    function testMintSimpleMockedReceiptVault(
        address receiptVault,
        address alice,
        address bob,
        uint256 maxShares,
        uint256 totalSupply,
        uint256 firstShares
    ) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();

        maxShares = bound(maxShares, 2e18, 1e27);
        totalSupply = bound(totalSupply, 0, 1e18);
        firstShares = bound(firstShares, 1, maxShares - totalSupply - 1);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), maxShares);

        assertEq(authorizer.owner(), bob, "Owner should be set to Bob");
        assertEq(1e27, paymentToken.balanceOf(alice), "Alice should have tokens initially");
        assertEq(0, paymentToken.balanceOf(bob), "Bob should have no tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), maxShares * 2);

        uint256 paymentAmount = firstShares;

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: firstShares,
                    sharesMinted: firstShares,
                    data: ""
                })
            )
        );

        assertEq(1e27 - paymentAmount, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            paymentAmount,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after mint"
        );
        assertEq(0, paymentToken.balanceOf(bob), "Bob should still have no tokens after mint");

        vm.prank(alice);
        authorizer.sendPaymentToOwner();

        assertEq(
            1e27 - paymentAmount, paymentToken.balanceOf(alice), "Alice should still have reduced balance after payment"
        );
        assertEq(paymentAmount, paymentToken.balanceOf(bob), "Bob should have received payment after send");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens after send");
    }

    function testZeroPaymentAmount(address receiptVault, address alice) external {
        vm.assume(uint160(alice) > type(uint160).max / 2);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, alice, address(paymentToken), 1e27);

        assertEq(authorizer.owner(), alice, "Owner should be set to Alice");
        assertEq(1e27, paymentToken.balanceOf(alice), "Alice should have tokens initially");
        assertEq(0, paymentToken.balanceOf(address(authorizer)), "Authorizer should have no tokens initially");

        bytes memory data = abi.encode(
            DepositStateChange({
                owner: alice,
                receiver: alice,
                id: 1,
                assetsDeposited: 0, // No assets deposited
                sharesMinted: 0, // No shares minted
                data: ""
            })
        );

        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, alice, DEPOSIT, data));
        authorizer.authorize(alice, DEPOSIT, data);
    }

    function testTokenDecimals(
        address receiptVault,
        address alice,
        address bob,
        uint8 decimals,
        uint256 maxShares,
        uint256 totalSupply,
        uint256 firstShares
    ) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        maxShares = bound(maxShares, 2e18, 1e27);
        totalSupply = bound(totalSupply, 0, 1e18);
        decimals = uint8(bound(decimals, 1, 17));

        firstShares = bound(firstShares, 1, maxShares - totalSupply - 1);
        uint256 paymentAmount = LibFixedPointDecimalScale.scaleN(firstShares, decimals, FLAG_ROUND_UP);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();
        paymentToken.setDecimals(decimals);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), maxShares);

        assertEq(authorizer.paymentTokenDecimals(), decimals, "Payment token decimals should be set to 18");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), maxShares * 2);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: firstShares,
                    sharesMinted: firstShares,
                    data: ""
                })
            )
        );

        assertEq(1e27 - paymentAmount, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            paymentAmount,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after mint"
        );
    }

    function testTofuTokenDecimals(
        address receiptVault,
        address alice,
        address bob,
        uint8 decimals,
        uint256 maxShares,
        uint256 totalSupply,
        uint256 firstShares
    ) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);
        vm.assume(uint160(receiptVault) > type(uint160).max / 2);

        maxShares = bound(maxShares, 2e18, 1e27);
        totalSupply = bound(totalSupply, 0, 1e18);
        decimals = uint8(bound(decimals, 1, 17));

        firstShares = bound(firstShares, 1, maxShares - totalSupply - 1);
        uint256 secondShares = bound(firstShares, 1, maxShares - totalSupply - firstShares);
        uint256 paymentAmount = LibFixedPointDecimalScale.scaleN(firstShares, decimals, FLAG_ROUND_UP);

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();
        paymentToken.setDecimals(decimals);

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(receiptVault, bob, address(paymentToken), maxShares);

        assertEq(authorizer.paymentTokenDecimals(), decimals, "Payment token decimals should be set");

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(totalSupply));

        vm.prank(alice);
        paymentToken.approve(address(authorizer), maxShares * 2);

        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: firstShares,
                    sharesMinted: firstShares,
                    data: ""
                })
            )
        );

        assertEq((1e27 - paymentAmount), paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            paymentAmount,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after second mint"
        );

        paymentToken.setDecimals(decimals + 1);
        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(PaymentTokenDecimalMismatch.selector, decimals, decimals + 1));
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: secondShares,
                    sharesMinted: secondShares,
                    data: ""
                })
            )
        );

        paymentToken.setDecimals(decimals);
        vm.prank(receiptVault);
        authorizer.authorize(
            alice,
            DEPOSIT,
            abi.encode(
                DepositStateChange({
                    owner: alice,
                    receiver: alice,
                    id: 1,
                    assetsDeposited: secondShares,
                    sharesMinted: secondShares,
                    data: ""
                })
            )
        );

        paymentAmount = paymentAmount + LibFixedPointDecimalScale.scaleN(secondShares, decimals, FLAG_ROUND_UP);

        assertEq(
            1e27 - paymentAmount, paymentToken.balanceOf(alice), "Alice should have reduced balance after second mint"
        );
        assertEq(
            paymentAmount,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after second mint"
        );
    }

    function testMaxSharesSupplyExceeded(
        address alice,
        address bob,
        uint256 maxShares,
        uint256 firstShares,
        uint256 secondShares,
        uint256 thirdShares
    ) external {
        vm.assume(alice != address(0) && bob != address(0) && alice != bob);

        OffchainAssetVaultConfigV2 memory offchainAssetVaultConfig = OffchainAssetVaultConfigV2({
            initialAdmin: bob,
            vaultConfig: VaultConfig({asset: address(0), name: "foo", symbol: "bar"})
        });
        // Use the factory to create the child contract
        OffchainAssetReceiptVault receiptVault = OffchainAssetReceiptVault(
            payable(I_FACTORY.clone(address(I_IMPLEMENTATION), abi.encode(offchainAssetVaultConfig)))
        );

        vm.prank(alice);
        TestErc20 paymentToken = new TestErc20();

        maxShares = bound(maxShares, 1e18, 1e27);
        firstShares = bound(firstShares, 1, maxShares);
        secondShares = bound(secondShares, maxShares - firstShares + 1, type(uint128).max);

        if (firstShares != maxShares) {
            thirdShares = bound(thirdShares, 1, maxShares - firstShares);
        }

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizer(address(receiptVault), bob, address(paymentToken), maxShares);

        assertEq(authorizer.maxSharesSupply(), maxShares, "Max shares supply should be set");

        vm.startPrank(bob);
        receiptVault.setAuthorizer(authorizer);
        authorizer.grantRole(CERTIFY, bob);
        receiptVault.certify(block.timestamp + 1, false, "");
        vm.stopPrank();

        vm.startPrank(alice);
        paymentToken.approve(address(authorizer), type(uint256).max);
        receiptVault.mint(firstShares, alice, 0, hex"");
        vm.stopPrank();

        assertEq(1e27 - firstShares, paymentToken.balanceOf(alice), "Alice should have reduced balance after mint");
        assertEq(
            firstShares,
            paymentToken.balanceOf(address(authorizer)),
            "Authorizer should have received tokens after mint"
        );

        vm.startPrank(alice);
        vm.expectRevert(abi.encodeWithSelector(MaxSharesSupplyExceeded.selector, maxShares, firstShares + secondShares));
        receiptVault.mint(secondShares, alice, 0, hex"");
        vm.stopPrank();

        if (firstShares != maxShares) {
            vm.startPrank(alice);
            receiptVault.mint(thirdShares, alice, 0, hex"");
            vm.stopPrank();

            assertEq(
                1e27 - firstShares - thirdShares,
                paymentToken.balanceOf(alice),
                "Alice should have reduced balance after second mint"
            );
            assertEq(
                firstShares + thirdShares,
                paymentToken.balanceOf(address(authorizer)),
                "Authorizer should have received tokens after second mint"
            );
        }
    }
}
