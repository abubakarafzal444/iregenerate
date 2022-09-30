//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Regenerative Pool
 */
interface IRegenerativePool {

    /**
     * @notice Stake ERC3525 token into Regenerative Pool with specific value.
     * this function will create new token
     * @param tokenIds_ The tokens to stake into
     * @param values_ The staked values for corresponding tokenId
     */
    function stake(uint256[] memory tokenIds_, uint256[] memory values_) external;

    function claim() external;

    function unstake(uint256[] memory tokenIds_) external;

    function unstake(uint256 tokenId_) external;

    function redeem(uint256[] memory tokenIds_) external;

    function redeem(uint256 tokenId_) external;
}
