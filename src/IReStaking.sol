//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReStaking {
    struct NftBalance {
        uint256 stakingAmount;
        uint256 burnableAmount;
    }

    struct StakingInfo {
        uint256 stakeNFTamount;
        uint256 leftToUnstakeNFTamount;
        uint256 staketime;
        uint256 unstaketime;
        bool isUnstake;
    }

    function nftBalance(address staker) external view returns (NftBalance memory);

    function stakingInfo(address staker, uint256 index) external view returns (StakingInfo memory);
}
