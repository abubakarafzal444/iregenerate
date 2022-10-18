// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract MockStake is ERC1155Holder {
    IERC1155 public ierc1155;

    struct StakingInfo {
        uint256 stakeNFTamount;
        uint256 leftToUnstakeNFTamount;
        uint256 staketime;
        uint256 unstaketime;
        bool isUnstake;
    }

    struct NftBalance {
        uint256 stakingAmount;
        uint256 burnableAmount;
    }

    mapping(address => StakingInfo[]) public stakingInfo;
    mapping(address => NftBalance) public nftBalance;
    mapping(address => uint256) public ClaimAmount;

    uint256 private AprByMin = 240 * 1e6 wei;
    uint256 private BurnReturn = 2_000 * 1e6 wei;
    uint256 public YearInSeconds = 31_536_000;

    event stakeInfo(address indexed user,uint256 stakeTime , uint256 amount , uint256 burnTime);

    constructor(address ierc1155_) {
        ierc1155 = IERC1155(ierc1155_);
    }

    function stake(uint256 bal) external {
        require(ierc1155.balanceOf(msg.sender, 1) >= bal, "Invalid input balance");
        require(bal > 0, "Can't stake zero");

        ierc1155.safeTransferFrom(msg.sender, address(this), 1, bal, "");

        uint256 startTime = block.timestamp;
        stakingInfo[msg.sender].push(StakingInfo(bal, bal, startTime, startTime, false));
        nftBalance[msg.sender].stakingAmount += bal;

        emit stakeInfo(msg.sender,block.timestamp , bal , startTime + YearInSeconds);
    }

    function unStake(uint256 unstakeAmount) external {
        require(nftBalance[msg.sender].stakingAmount >= unstakeAmount, "You don't have enough staking NFTs");
        uint256 leftToUnstakeAmount = unstakeAmount;
        uint256 unstakeTime = block.timestamp;

        ClaimAmount[msg.sender] += StakingReward_Balance(msg.sender);
        for (uint256 i = 0; i < stakingInfo[msg.sender].length; i++) {
            if (stakingInfo[msg.sender][i].isUnstake) continue;
            if (leftToUnstakeAmount == 0) break;

            StakingInfo storage stakeRecord = stakingInfo[msg.sender][i];
            if (leftToUnstakeAmount >= stakeRecord.leftToUnstakeNFTamount) {
                leftToUnstakeAmount -= stakeRecord.leftToUnstakeNFTamount;
                stakeRecord.leftToUnstakeNFTamount = 0;
                stakeRecord.isUnstake = true;
            } else {
                stakeRecord.leftToUnstakeNFTamount -= leftToUnstakeAmount;
                leftToUnstakeAmount = 0;
            }
            stakeRecord.unstaketime = unstakeTime;
        }

        nftBalance[msg.sender].stakingAmount -= unstakeAmount;
        ierc1155.safeTransferFrom(address(this), msg.sender, 1, unstakeAmount, "");
    }

    function StakingReward_Balance(address stakingAddress)
        public
        view
        returns (uint256)
    {
        uint256 balance = 0;

        for (uint256 i = 0; i < stakingInfo[stakingAddress].length; i++) {
            StakingInfo memory stakeRecord = stakingInfo[stakingAddress][i];
            if (stakeRecord.isUnstake) continue;

            balance += stakeRecord.leftToUnstakeNFTamount *
                (block.timestamp - stakeRecord.unstaketime) *
                (AprByMin / YearInSeconds);
        }

        return balance;
    }

    function CheckClaimValue(address user) public view returns (uint256) {
        uint256 claimAmount = StakingReward_Balance(user) + ClaimAmount[user];
        return claimAmount;
    }
}