//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC165.sol";

/**
 * @title Regenerative Pool
 */
interface IRegenerativePool is IERC165 {

    /**
     * @notice Get the balance of staking tokens from the owner
     * @param _owner The staker address
     */
    function balanceOf(address _owner) external view returns (uint256);

    /**
     * @notice Stake ERC3525 tokens into Regenerative Pool with specific values.
     * this function will create new tokens if the user only stakes partial values.
     * @param _tokenIds The tokens to stake into
     * @param _values The staked value for corresponding tokenId
     */
    function stake(uint256[] memory _tokenIds, uint256[] memory _values) external;

    /**
     * @notice Stake ERC3525 token into Regenerative Pool with specific value.
     * this function will create new token if the user only stakes partial value.
     * @param _tokenId The tokens to stake into
     * @param _value The staked value that the user wants to stake tokenId
     */
    function stake(uint256 _tokenId, uint256 _value) external;

    /**
     * @notice Claim interests from all staking ERC3525 tokens
     */
    function claim() external;

    /**
     * @notice Unstake ERC3525 tokens from the staking contract
     * @param _tokenIds the token Ids that the staker wants to unstake
     */
    function unstake(uint256[] memory _tokenIds) external;

    /**
     * @notice Unstake one ERC3525 token from the staking contract
     * @param _tokenId the token Id that the staker want to unstake
     */
    function unstake(uint256 _tokenId) external;

    /**
     * @notice Redeem principal with bonus interests from all selected ERC3525 tokens
     * @param _tokenIds the token ids that staker wants to redeem
     */
    function redeem(uint256[] memory _tokenIds) external;

    /**
     * @notice Redeem principal with bonus interests from one selected ERC3525 token
     * @param _tokenId the token id that staker wants to redeem
     */
    function redeem(uint256 _tokenId) external;
}
