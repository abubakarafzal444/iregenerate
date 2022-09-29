//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Regenerative Pool
 */
interface IRegenerativePool {

    /**
     * @notice Stake ERC3525 token into Regenerative Pool with specific value.
     * this function will create new token
     * @param tokenId_ The token to stake into
     * @param value_ The staked value
     */
    function stake(uint256 tokenId_, uint256 value_) external;

    /**
     * @notice 
     */
    function stake(uint256 tokenId_) external;

    function claim() external;

    function unstake(uint256[] memory tokenIds_) external;

    function unstake(uint256 tokenId_) external;

    function redeem(uint256[] memory tokenIds_) external;

    function redeem(uint256 tokenId_) external;
}
