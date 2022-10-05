//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Regenerative Pool
 */
interface IRegenerativePool {

    /**
     * @notice Stake ERC3525 tokens into Regenerative Pool with specific values.
     * this function will create new tokens if the user only stakes partial values.
     * @param tokenIds_ The tokens to stake into
     * @param values_ The staked value for corresponding tokenId
     */
    function stake(uint256[] memory tokenIds_, uint256[] memory values_) external;

    /**
     * @notice Stake ERC3525 token into Regenerative Pool with specific value.
     * this function will create new token if the user only stakes partial value.
     * @param tokenId_ The tokens to stake into
     * @param value_ The staked value that the user wants to stake tokenId
     */
    function stake(uint256 tokenId_, uint256 value_) external;

    /**
     * @notice Claim interests from all staking ERC3525 tokens
     */
    function claim() external;

    /**
     * @notice Unstake ERC3525 tokens from the staking contract
     * @param tokenIds_ the token Ids that the staker wants to unstake
     */
    function unstake(uint256[] memory tokenIds_) external;

    /**
     * @notice Unstake one ERC3525 token from the staking contract
     * @param tokenId_ the token Id that the staker want to unstake
     */
    function unstake(uint256 tokenId_) external;

    /**
     * @notice Redeem principal with bonus interests from all selected ERC3525 tokens
     * @param tokenIds_ the token ids that staker wants to redeem
     */
    function redeem(uint256[] memory tokenIds_) external;

    /**
     * @notice Redeem principal with bonus interests from one selected ERC3525 token
     * @param tokenId_ the token id that staker wants to redeem
     */
    function redeem(uint256 tokenId_) external;
}
