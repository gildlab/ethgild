// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Open Zeppelin imports.
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

// EthGild import for reentrancy.
import {EthGild} from "../ethgild.sol";

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
        uint256 id,
        uint256 value,
        bytes calldata
    ) external override returns (bytes4) {
        if (value > 100) {
            erc1155Received = [id, value];
            EthGild(msg.sender).ungild(id, 50);
            return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
        } else {
            return bytes4(keccak256("garbage"));
        }
    }

    receive() payable external {
        require(msg.value > 10, "LOW_VALUE");
        didReceivePayable = true;
    }

    /// Ungilds too little ETH to satisfy the receive.
    /// Reentrant call should fail.
    function lowValueUngild(EthGild ethGild, uint256 id) external {
        ethGild.ungild(id, 5);
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
    function supportsInterface(bytes4 interfaceID) external pure override returns (bool) {
        return  interfaceID == 0x01ffc9a7 ||    // ERC-165 support (i.e. `bytes4(keccak256('supportsInterface(bytes4)'))`).
                interfaceID == 0x4e2312e0;      // ERC-1155 `ERC1155TokenReceiver` support (i.e. `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)")) ^ bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`).
    }
}