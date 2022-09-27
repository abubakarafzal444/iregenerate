//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Constants.sol";

interface IReStaking {
    function nftBalance(address staker)
        external
        view
        returns (Constants.NftBalance memory);

    function stakingInfo(address staker, uint256 index)
        external
        view
        returns (Constants.StakingInfo memory);
}