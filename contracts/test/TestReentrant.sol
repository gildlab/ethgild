// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Open Zeppelin imports.
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

// EthGild import for reentrancy.
import {NativeGild} from "../gild/NativeGild.sol";

/// @title TestReentrant
/// @author thedavidmeister
///
/// Only use is to test/show reentrant behaviour in EthGild.
contract TestReentrant is IERC1155Receiver {
    bool public didReceivePayable;
    uint256[2] public erc1155Received;

    /// @inheritdoc IERC1155Receiver
    function onERC1155Received(
        address,
        address,
        uint256 id_,
        uint256 value_,
        bytes calldata
    ) external override returns (bytes4) {
        // Exact value sent by lowValueUngild is 1234.
        if (value_ <= 1234) {
            return bytes4(keccak256("garbage"));
        }
        if (value_ > 10000) {
            erc1155Received = [id_, value_];
            NativeGild(msg.sender).gild{value: 1500}();
            NativeGild(msg.sender).ungild(
                uint8(id_ & 0xFF),
                id_ >> 8,
                (value_ * 1000) / 1001
            );
        }
        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    receive() external payable {
        require(msg.value > 1100, "LOW_VALUE");
        didReceivePayable = true;
    }

    /// Ungilds too little ETH to satisfy the receive.
    /// Reentrant call should fail.
    function lowValueUngild(NativeGild nativeGild, uint256 id) external {
        nativeGild.ungild(8, id, 1234);
    }

    function gild(NativeGild nativeGild) external payable {
        nativeGild.gild{value: msg.value / 2}();
    }

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
    function supportsInterface(bytes4 interfaceID)
        external
        pure
        override
        returns (bool)
    {
        return
            interfaceID == 0x01ffc9a7 || // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
            interfaceID == 0x4e2312e0; // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    }
}
