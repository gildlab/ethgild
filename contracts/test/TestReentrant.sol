// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Open Zeppelin imports.
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import {NativeGild} from "../gild/NativeGild.sol";

/// @title TestReentrant
/// @author thedavidmeister
///
/// Only use is to test/show reentrant behaviour in EthGild.
contract TestReentrant is IERC1155Receiver {
    bool private shouldUngild;

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address,
        address,
        uint256 id_,
        uint256 value_,
        bytes calldata
    ) external override returns (bytes4) {
        if (shouldUngild) {
            NativeGild(msg.sender).ungild(id_, (value_ * 1000) / 1001);
        } else {
            NativeGild(msg.sender).gild{value: 1500}();
        }
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    function gild(NativeGild nativeGild_, bool shouldUngild_) external payable {
        shouldUngild = shouldUngild_;
        nativeGild_.gild{value: msg.value / 2}();
    }

    //solhint-disable-next-line no-empty-blocks
    receive() external payable { }

    /// @inheritdoc IERC1155Receiver
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        // EthGild never calls this.
        assert(false);
        return bytes4(keccak256("more garbage"));
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceID_)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceID_ == 0x01ffc9a7 || // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
            interfaceID_ == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    }
}
