// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/RegenerativeNFT.sol";
import "../src/ERC3525/IERC3525.sol";
import "../src/ERC3525/ERC3525Holder.sol";
import "../src/IReStaking.sol";
import "../src/IRegenerative.sol";
import "../src/IRegenerativePool.sol";
import "../src/RegenerativeCore.sol";
import "../src/Constants.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "../src/UUPSProxy.sol";

contract RegenerativeTest is Test {
    UUPSProxy nftProxy;
    UUPSProxy poolProxy;
    RegenerativeNFT nftLogic;
    RegenerativePool poolLogic;

    function setUp() public {
        nftLogic = new RegenerativeNFT();
        poolLogic = new RegenerativePool();
        nftProxy = new UUPSProxy(
            address(nftLogic),
            abi.encodeWithSelector(
                nftLogic.initialize.selector,
                "RegenerativeNFT",
                "RGT",
                6
            )
        );
        poolProxy = new UUPSProxy(
            address(poolLogic),
            abi.encodeWithSelector(
                poolLogic.initialize.selector,
                address(nftProxy),
                block.timestamp + 8_640_000
            )
        );
    }

    function testValueDecimals() public {
        (bool success, bytes memory result) = address(nftProxy).call(
            abi.encodeWithSignature("valueDecimals()")
        );
        if (success) {
            uint8 decimals = abi.decode(result, (uint8));
            emit log_uint(decimals);
        }
    }
}


contract RegenerativePool is
    Ownable,
    UUPSUpgradeable,
    Initializable,
    RegenerativeCore,
    ERC3525Holder,
    IRegenerativePool
{
    uint256 public LOCK_TIME;

    function initialize(address ierc3525_, uint256 locktime_)
        public
        initializer
    {
        erc3525 = IERC3525(ierc3525_);
        iregenerative = IRegenerative(ierc3525_);
        LOCK_TIME = locktime_;
    }

    // test func
    function checkNftBalance(address staker)
        external
        view
        returns (uint256 staked)
    {
        return IReStaking(Constants.RE_STAKE).nftBalance(staker).stakingAmount;
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
        Constants.StakingInfo memory stakingInfo = IReStaking(
            Constants.RE_STAKE
        ).stakingInfo(staker, index);
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
        _storeReStakeDurations(staker);
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
     *  stake functions
     *  the decimals of value_ is valueDecimals_
     */
    function stake(uint256 tokenId_, uint256 value_) public {
        if (msg.sender != erc3525.ownerOf(tokenId_))
            revert Constants.NotOwner();

        _stake(tokenId_, value_);
    }

    function stake(uint256 tokenId_) external {
        stake(tokenId_, 0);
    }

    /**
        claim related functions
     */
    function claim() external {
        if (block.timestamp < LOCK_TIME) revert Constants.NotClamiable();

        _claim(_stakingIds[msg.sender], block.timestamp);
    }

    /**
        unstake functions
     */
    function unstake(uint256[] memory tokenIds_) public {
        _storeReStakeDurations(msg.sender);
        _unstake(tokenIds_, block.timestamp);
    }

    function unstake(uint256 tokenId_) external {
        uint256[] memory tokenIds_ = new uint256[](1);
        tokenIds_[0] = tokenId_;
        unstake(tokenIds_);
    }

    /**
        redeem functions
     */
    function redeem(uint256[] memory tokenIds_) public {
        _storeReStakeDurations(msg.sender);
        _redeem(tokenIds_);
    }

    function redeem(uint256 tokenId_) external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId_;
        redeem(tokenIds);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}