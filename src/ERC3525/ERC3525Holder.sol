// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC3525Receiver.sol";

/**
 * @dev Implementation of the {IERC3525Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC3525Receiver-safeTransferFrom}, {IERC3525Receiver-approve} or {IERC3525Receiver-setApprovalForAll}.
 */
contract ERC3525Holder is IERC3525Receiver {
    /**
     * @dev See {IERC3525Receiver-onERC3525Received}.
     *
     * Always returns `IERC3525Receiver.onERC3525Received.selector`.
     */
    function onERC3525Received(
        address,
        uint256,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC3525Received.selector;
    }
}
