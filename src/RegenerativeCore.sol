// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC3525/IERC3525.sol";
import "./IReStaking.sol";
import "./IRegenerative.sol";
import "./Constants.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";

abstract contract RegenerativeCore {
    struct Duration {
        uint64 start;
        uint64 end;
    }

    struct StakingInfo {
        uint256 staketime;
        uint256 unstaketime;
        uint256 claimtime;
    }

    event Stake(
        address indexed from_,
        uint256 indexed tokenId_,
        uint256 value_
    );
    event Unstake(address indexed to_, uint256 indexed tokenId_);
    event Claim(address indexed to_, uint256 balance);
    event Redeem(address indexed to_, uint256 value_);

    IERC3525 public erc3525;
    IRegenerative public iregenerative;

    // The durations of Re Staking Records
    mapping(address => Duration[]) _reStakingDurations;
    mapping(address => uint256) _reStakingIndex;

    // tokenId => stakingInfo
    mapping(uint256 => StakingInfo) _stakingInfos;

    // staker => tokenIds
    mapping(address => uint256[]) _stakingIds;
    mapping(uint256 => uint256) _tokenIdsIndex;

    function _stake(uint256 tokenId_, uint256 value_) internal {
        uint256 currtime = block.timestamp;
        uint256 tokenId = tokenId_;
        uint256 value = value_;

        _stakingInfos[tokenId_] = StakingInfo({
            staketime: currtime,
            unstaketime: 0,
            claimtime: currtime
        });

        if (value_ == 0) {
            // stake tokenId_ into the contract
            erc3525.safeTransferFrom(msg.sender, address(this), tokenId_);
            value = erc3525.balanceOf(tokenId_);
        } else {
            // split tokenId_ to newTokenId then stake into the contract
            tokenId = erc3525.transferFrom(tokenId_, address(this), value_);
        }

        _tokenIdsIndex[tokenId] = _stakingIds[msg.sender].length;
        _stakingIds[msg.sender].push(tokenId);

        emit Stake(msg.sender, tokenId, value);
    }

    function _claim(uint256[] memory tokenIds_, uint256 currtime_) internal {
        uint256 balance = 0;
        uint256 length = tokenIds_.length;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds_[i];
            balance += _calculateClaimableYield(
                tokenId,
                currtime_ - _stakingInfos[tokenId].claimtime,
                Constants.YieldType.BASE_APR
            );
            _stakingInfos[tokenId].claimtime = currtime_;
        }
        IERC20(Constants.USDC).transfer(msg.sender, balance);
        emit Claim(msg.sender, balance);
    }

    function _unstake(uint256[] memory tokenIds_, uint256 currtime_) internal {
        uint256 length = tokenIds_.length;
        uint256 balance = 0;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds_[i];

            if (tokenId != _stakingIds[msg.sender][_tokenIdsIndex[tokenId]])
                revert Constants.NotStaker();

            balance += _calculateClaimableYield(
                tokenId,
                currtime_ - _stakingInfos[tokenId].claimtime,
                Constants.YieldType.BASE_APR
            );

            _stakingInfos[tokenIds_[i]].unstaketime = currtime_;

            iregenerative.updateStakeDataByTokenId(
                tokenId,
                _calculateHighYieldSecs(tokenId)
            );

            _removeTokenIdFromStakesEnumeration(tokenId);

            erc3525.safeTransferFrom(address(this), msg.sender, tokenId);
            emit Unstake(msg.sender, tokenId);
        }

        IERC20(Constants.USDC).transfer(msg.sender, balance);
        emit Claim(msg.sender, balance);
    }

    function _removeTokenIdFromStakesEnumeration(uint256 tokenId_) internal {
        uint256 tokenIndex = _tokenIdsIndex[tokenId_];
        uint256 lastIndex = _stakingIds[msg.sender].length - 1;
        _stakingIds[msg.sender][tokenIndex] = _stakingIds[msg.sender][
            lastIndex
        ];
        _stakingIds[msg.sender].pop();
    }

    function _redeem(uint256[] memory tokenIds_) internal {
        uint256 length = tokenIds_.length;
        uint256 principal = 0;
        uint256 bonusYield = 0;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds_[i];
            if (msg.sender != erc3525.ownerOf(tokenId))
                revert Constants.NotOwner();

            principal += erc3525.balanceOf(tokenId);
            bonusYield += _calculateClaimableYield(
                tokenId,
                iregenerative.highYieldSecsOf(tokenId),
                Constants.YieldType.BONUS_APR
            );

            delete _stakingInfos[tokenId];

            iregenerative.burn(tokenId);
        }

        IERC20(Constants.USDC).transfer(msg.sender, principal + bonusYield);
        emit Redeem(msg.sender, principal);
        emit Claim(msg.sender, bonusYield);
    }

    function _calculateClaimableYield(
        uint256 tokenId_,
        uint256 secs_,
        Constants.YieldType yieldType_
    ) internal view returns (uint256) {
        uint256 apr = 0;
        if (yieldType_ == Constants.YieldType.BONUS_APR) {
            apr = Constants.HIGH_APR - Constants.BASE_APR;
        } else if (yieldType_ == Constants.YieldType.BASE_APR) {
            apr = Constants.BASE_APR;
        }
        return
            (secs_ * apr * erc3525.balanceOf(tokenId_)) /
            (Constants.YEAR_IN_SECS * Constants.PERCENTAGE);
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

    function _storeReStakeDurations(address staker) internal {
        // Re StakingInfo index whose isUnstake is false
        uint256 start = _reStakingIndex[staker];
        Duration memory newDuration;
        for (uint256 i = start; i < 2**256 - 1; i++) {
            try IReStaking(Constants.RE_STAKE).stakingInfo(staker, i) returns (
                Constants.StakingInfo memory stakingInfo
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
                if (reason.length != 0) break;
            }
        }
    }
}
