// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.0;

contract ERC1155AltURI {
    /// Sender asserts that there is a URI to interact with ETHGild on.
    /// The URI may be malicious and steal funds so end-users are strongly
    /// encouraged to carefully consider their reasons for trusting `sender`.
    event AltURI(
        /// `msg.sender` logging the new alt URI.
        address sender,
        /// Alternative URI the erc1155 can be found at.
        string altURI
    );

    /// Log an alternative URI that the sender claims is handling `EthGild`.
    /// The URI may trivially be malicious so end users are strongly encouraged
    /// to carefully consider their reasons for trusting `msg.sender` to not
    /// steal funds.
    /// @param altUri_ The alternative URI for `EthGild` 1155 tokens.
    function altURI(string calldata altUri_) external {
        emit AltURI(msg.sender, altUri_);
    }
}