// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./IERC3525.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "./ERC3525Holder.sol";

library StructLib {
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
}

interface ReStaking {
    function nftBalance(address staker)
        external
        view
        returns (StructLib.NftBalance memory);

    function stakingInfo(address staker, uint256 index)
        external
        view
        returns (StructLib.StakingInfo memory);
}

interface RegenerativeNFT {
    function isApprovedForAll(address owner_, address operator_)
        external
        view
        returns (bool);

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) external;

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) external;

    function transferFrom(
        address from_,
        address to_,
        uint256 value_
    ) external returns (uint256);

    function balanceOf(address owner_) external view returns (uint256 balance);

    function balanceOf(uint256 tokenId_) external view returns (uint256);

    function tokenOfOwnerByIndex(address owner_, uint256 index_)
        external
        view
        returns (uint256);

    function updateHighYieldSecsByTokenId(uint256 tokenId_, uint256 secs_)
        external;

    function highYieldSecsOf(uint256 tokenId_) external returns (uint256);

    function burn(uint256 tokenId_) external;
}

error NotOwner();
error NotApproved();
error NotClamiable();

contract RegenerativeStake is ERC3525Holder {
    struct Duration {
        uint64 start;
        uint64 end;
    }

    struct StakingInfo {
        uint256 staketime;
        uint256 unstaketime;
        uint256 claimtime;
    }

    address constant RE_STAKING = 0x7dabFb9b6DE663A83Aa3e6639813855A9Dd853c1;
    address constant REGENERATIVE_NFT = address(0);
    address constant USDC = address(0);

    // NFT contract init time + 3 months
    uint256 constant LOCK_TIME = 1235468;

    uint256 constant BASE_APR = 15;
    uint256 constant HIGH_APR = 25;

    // The durations of Re Staking Records
    mapping(address => Duration[]) _reStakingDurations;
    mapping(address => uint256) _reStakingIndex;

    // tokenId => stakingInfo
    mapping(uint256 => StakingInfo) _stakingInfos;

    // staker => tokenIds
    mapping(address => uint256[]) _stakingIds;
    mapping(uint256 => uint256) _tokenIdsIndex;

    event Stake(
        address indexed from_,
        uint256 indexed tokenId_,
        uint256 value_
    );
    event Unstake(address indexed to_, uint256 indexed tokenId_);
    event Claim(address indexed to_, uint256 balance);
    event Redeem(address indexed to_, uint256 value_);

    // test func
    function checkNftBalance(address staker)
        external
        view
        returns (uint256 staked)
    {
        return ReStaking(RE_STAKING).nftBalance(staker).stakingAmount;
    }

    // test func
    function checkStakingInfo(address staker, uint256 index)
        public
        view
        returns (
            uint256 staked,
            uint256 leftToUnstake,
            uint256 stakeTime,
            uint256 unstakeTime,
            bool isUnstake
        )
    {
        StructLib.StakingInfo memory stakingInfo = ReStaking(RE_STAKING)
            .stakingInfo(staker, index);
        return (
            stakingInfo.stakeNFTamount,
            stakingInfo.leftToUnstakeNFTamount,
            stakingInfo.staketime,
            stakingInfo.unstaketime,
            stakingInfo.isUnstake
        );
    }

    // test func
    function getReStakingDurationsByAddress(address staker)
        public
        returns (uint64[] memory, uint64[] memory)
    {
        _storeReStakingDurations(staker);
        uint256 length = _reStakingDurations[staker].length;

        uint64[] memory starts = new uint64[](length);
        uint64[] memory ends = new uint64[](length);
        for (uint256 i = 0; i < length; i++) {
            starts[i] = _reStakingDurations[staker][i].start;
            ends[i] = _reStakingDurations[staker][i].end;
        }
        return (starts, ends);
    }

    /**
        stake functions
     */
    function stake(uint256 tokenId_, uint256 value_) public {
        if (msg.sender != IERC3525(REGENERATIVE_NFT).ownerOf(tokenId_))
            revert NotOwner();

        uint256 currtime = block.timestamp;
        uint256 tokenId = tokenId_;
        uint256 value = value_;

        _stakingInfos[tokenId_] = StakingInfo({
            staketime: currtime,
            unstaketime: 0,
            claimtime: currtime
        });

        _tokenIdsIndex[tokenId_] = _stakingIds[msg.sender].length;
        _stakingIds[msg.sender].push(tokenId_);

        if (value_ == 0) {
            // stake tokenId_ into the contract
            RegenerativeNFT(REGENERATIVE_NFT).safeTransferFrom(
                msg.sender,
                address(this),
                tokenId_
            );
            value = RegenerativeNFT(REGENERATIVE_NFT).balanceOf(tokenId_);
        } else {
            // split tokenId_ to newTokenId then stake into the contract
            tokenId = RegenerativeNFT(REGENERATIVE_NFT).transferFrom(
                msg.sender,
                address(this),
                value_
            );
        }

        emit Stake(msg.sender, tokenId, value_);
    }

    function stake(uint256 tokenId_) external {
        stake(tokenId_, 0);
    }

    /**
        claim related functions
     */

    function claim() external {
        if (block.timestamp < LOCK_TIME) revert NotClamiable();
        uint256 currtime = block.timestamp;
        // claim all yields from staking NFTs whose owner is msg.sender
        uint256[] memory stakingIds = _stakingIds[msg.sender];
        uint256 balance = _calculateClaimableYield(stakingIds, currtime);
        _updateClaimtime(stakingIds, currtime);

        IERC20(USDC).transfer(msg.sender, balance);
        emit Claim(msg.sender, balance);
    }

    function _updateClaimtime(uint256[] memory tokenIds_, uint256 currtime)
        internal
    {
        uint256 length = tokenIds_.length;
        for (uint256 i = 0; i < length; i++) {
            _stakingInfos[tokenIds_[i]].claimtime = currtime;
        }
    }

    function getClaimableYieldByAddress(address staker)
        public
        view
        returns (uint256)
    {
        return _calculateClaimableYield(_stakingIds[staker], block.timestamp);
    }

    function _calculateClaimableYield(
        uint256[] memory stakingIds_,
        uint256 currtime_
    ) internal view returns (uint256) {
        uint256 balance = 0;
        uint256 length = stakingIds_.length;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = stakingIds_[i];
            balance +=
                ((currtime_ - _stakingInfos[tokenId].claimtime) *
                    RegenerativeNFT(REGENERATIVE_NFT).balanceOf(tokenId) *
                    15) /
                31_536_000 /
                100;
        }

        return balance;
    }

    /**
        unstake functions
     */
    function unstake(uint256[] memory tokenIds_) public {
        _storeReStakingDurations(msg.sender);

        uint256 currtime = block.timestamp;
        uint256 length = tokenIds_.length;

        uint256 balance = _calculateClaimableYield(tokenIds_, currtime);
        _updateUnstaketime(tokenIds_, currtime);
        _updateClaimtime(tokenIds_, currtime);

        for (uint256 i = 0; i < length; i++) {
            RegenerativeNFT(REGENERATIVE_NFT).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds_[i]
            );
            RegenerativeNFT(REGENERATIVE_NFT).updateHighYieldSecsByTokenId(
                tokenIds_[i],
                _calculateHighYieldSecs(tokenIds_[i])
            );
            _removeTokenIdFromStakingIds(tokenIds_[i]);
            emit Unstake(msg.sender, tokenIds_[i]);
        }

        IERC20(USDC).transfer(msg.sender, balance);
        emit Claim(msg.sender, balance);
    }

    function unstake(uint256 tokenId_) external {
        uint256[] memory tokenIds_ = new uint256[](1);
        tokenIds_[0] = tokenId_;
        unstake(tokenIds_);
    }

    function _removeTokenIdFromStakingIds(uint256 tokenId_) internal {
        uint256 tokenIndex = _tokenIdsIndex[tokenId_];
        uint256 lastIndex = _stakingIds[msg.sender].length - 1;
        _stakingIds[msg.sender][tokenIndex] = _stakingIds[msg.sender][
            lastIndex
        ];
        _stakingIds[msg.sender].pop();
    }

    function _updateUnstaketime(uint256[] memory tokenIds_, uint256 currtime_)
        internal
    {
        uint256 length = tokenIds_.length;
        for (uint256 i = 0; i < length; i++) {
            _stakingInfos[tokenIds_[i]].unstaketime = currtime_;
        }
    }

    function _calculateHighYieldSecs(uint256 tokenId)
        internal
        view
        returns (uint256)
    {
        uint256 highYieldSecs = 0;

        StakingInfo memory stakingInfo = _stakingInfos[tokenId];

        uint256 length = _reStakingDurations[msg.sender].length;
        for (uint256 j = 0; j < length; j++) {
            Duration memory reStakingDuration = _reStakingDurations[msg.sender][
                j
            ];
            // this Re staking duration is behind
            // this staking info
            if (reStakingDuration.start >= stakingInfo.unstaketime) break;
            // this Re staking duration is prior to
            // this staking info
            if (reStakingDuration.end <= stakingInfo.staketime) continue;
            uint256 start = reStakingDuration.start <= stakingInfo.staketime
                ? stakingInfo.staketime
                : reStakingDuration.start;
            uint256 end = reStakingDuration.end > 0
                ? reStakingDuration.end <= stakingInfo.unstaketime
                    ? reStakingDuration.end
                    : stakingInfo.unstaketime
                : stakingInfo.unstaketime;

            uint256 duration = end - start;
            highYieldSecs += duration;
        }
        return highYieldSecs;
    }

    function _storeReStakingDurations(address staker) internal {
        // Re StakingInfo index whose isUnstake is false
        uint256 start = _reStakingIndex[staker];
        Duration memory newDuration;
        for (uint256 i = start; i < 2**256 - 1; i++) {
            try ReStaking(RE_STAKING).stakingInfo(staker, i) returns (
                StructLib.StakingInfo memory stakingInfo
            ) {
                if (stakingInfo.isUnstake) {
                    newDuration = Duration({
                        start: uint64(stakingInfo.staketime),
                        end: uint64(stakingInfo.unstaketime)
                    });
                    if (i > 0) {
                        Duration storage prevDuration = _reStakingDurations[
                            staker
                        ][_reStakingDurations[staker].length - 1];
                        if (prevDuration.end == newDuration.end) {
                            continue;
                        } else if (prevDuration.end > newDuration.start) {
                            prevDuration.end = newDuration.end;
                            continue;
                        }
                    }
                    _reStakingDurations[staker].push(newDuration);
                    _reStakingIndex[staker]++;
                } else if (
                    stakingInfo.staketime !=
                    _reStakingDurations[staker][start].start &&
                    !stakingInfo.isUnstake
                ) {
                    newDuration = Duration({
                        start: uint64(stakingInfo.staketime),
                        end: 0
                    });
                    _reStakingDurations[staker].push(newDuration);
                }
            } catch (bytes memory reason) {
                break;
            }
        }
    }

    /**
        redeem functions
     */
    function redeem(uint256[] memory tokenIds_) public {
        uint256 length = tokenIds_.length;
        uint256 principal = 0;
        uint256 highYield = 0;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenIndex = _tokenIdsIndex[tokenIds_[i]];
            uint256 tokenId = _stakingIds[msg.sender][tokenIndex];
            principal += RegenerativeNFT(REGENERATIVE_NFT).balanceOf(tokenId);
            _removeTokenIdFromStakingIds(tokenId);

            highYield += _calculateHighYield(
                tokenId,
                RegenerativeNFT(REGENERATIVE_NFT).highYieldSecsOf(tokenId)
            );

            RegenerativeNFT(REGENERATIVE_NFT).updateHighYieldSecsByTokenId(
                tokenId,
                0
            );

            RegenerativeNFT(REGENERATIVE_NFT).burn(tokenId);
        }

        IERC20(USDC).transfer(msg.sender, principal + highYield);
        emit Redeem(msg.sender, principal);
        if (highYield > 0) {
            emit Claim(msg.sender, highYield);
        }
    }

    function redeem(uint256 tokenId_) external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId_;
        redeem(tokenIds);
    }

    function _calculateHighYield(uint256 tokenId_, uint256 secs_)
        internal
        view
        returns (uint256)
    {
        return
            (secs_ *
                (HIGH_APR - BASE_APR) *
                RegenerativeNFT(REGENERATIVE_NFT).balanceOf(tokenId_)) /
            31_536_000 /
            100;
    }
}
