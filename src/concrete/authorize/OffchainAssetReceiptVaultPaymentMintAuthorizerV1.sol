// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {IAuthorizeV1, Unauthorized} from "../../interface/IAuthorizeV1.sol";

import {ICloneableV2, ICLONEABLE_V2_SUCCESS} from "rain.factory/interface/ICloneableV2.sol";
import {IERC165Upgradeable as IERC165} from
    "openzeppelin-contracts-upgradeable/contracts/utils/introspection/IERC165Upgradeable.sol";
import {Initializable} from "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import {SafeERC20Upgradeable as SafeERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20Upgradeable as IERC20} from
    "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import {DEPOSIT, DepositStateChange} from "../vault/OffchainAssetReceiptVault.sol";
import {OwnableUpgradeable as Ownable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

error ZeroInitialOwner();

error ZeroPaymentToken();

struct OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config {
    address owner;
    address paymentToken;
}

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1 is
    IAuthorizeV1,
    ICloneableV2,
    IERC165,
    Initializable,
    Ownable
{
    using SafeERC20 for IERC20;

    address internal sPaymentToken;

    constructor() {
        _disableInitializers();
    }

    /// @inheritdoc ICloneableV2
    function initialize(bytes calldata data) external initializer returns (bytes32) {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config memory config =
            abi.decode(data, (OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config));

        if (config.paymentToken == address(0)) {
            revert ZeroPaymentToken();
        }

        if (config.owner == address(0)) {
            revert ZeroInitialOwner();
        }
        sPaymentToken = config.paymentToken;

        _transferOwnership(config.owner);

        return ICLONEABLE_V2_SUCCESS;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external view virtual override returns (bool) {
        return interfaceId == type(IAuthorizeV1).interfaceId || interfaceId == type(ICloneableV2).interfaceId;
    }

    /// @inheritdoc IAuthorizeV1
    function authorize(address, bytes32 permission, bytes calldata data) external virtual override {
        if (permission == DEPOSIT) {
            DepositStateChange memory stateChange = abi.decode(data, (DepositStateChange));
            IERC20(sPaymentToken).safeTransferFrom(stateChange.owner, address(this), stateChange.sharesMinted);
        }
    }

    function sendPaymentToOwner() external {
        IERC20(sPaymentToken).safeTransfer(owner(), IERC20(sPaymentToken).balanceOf(address(this)));
    }
}
