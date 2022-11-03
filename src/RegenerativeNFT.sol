// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC1155.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "./ERC3525/ERC3525SlotEnumerableUpgradeable.sol";
import "./IRegenerative.sol";
import "./IReStaking.sol";
import "./RegenerativeUtils.sol";

interface AssetChecker {
    struct TokenData {
        address originator;
        uint256 assetValue;
        uint256 maturity;
    }

    function data(uint256 _tokenId) external returns (TokenData memory);
}

contract RegenerativeNFT is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC3525SlotEnumerableUpgradeable,
    ERC721Holder,
    IRegenerative
{
    address public _currency;
    uint256 public LOCK_TIME;

    // The durations of Re Staking Records
    mapping(address => Duration[]) _reStakingDurations;
    mapping(address => uint256) _reStakingIndex;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address currency_
    ) external initializer {
        ERC3525Upgradeable.__ERC3525_init(name_, symbol_, decimals_);
        OwnableUpgradeable.__Ownable_init();
        _currency = currency_;
        LOCK_TIME = block.timestamp + RegenerativeUtils.LOCK_TIME;
    }

    function maturityOf(uint256 tokenId_) public view returns (uint256) {
        if (!_exists(tokenId_)) return 0;
        return
            ERC3525Upgradeable.getTokenSnapshot(tokenId_).mintTime +
            ERC3525SlotEnumerableUpgradeable
                .getSlotSnapshot(ERC3525Upgradeable.slotOf(tokenId_))
                .maturity;
    }

    function balanceOfSlot(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        return getSlotSnapshot(slot_).mintableValue;
    }

    function slotTotalValue(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        SlotData memory slotdata = getSlotSnapshot(slot_);
        return slotdata.rwaValue * slotdata.rwaAmount;
    }

    modifier onlyOriginator(uint256 slot_) {
        if (_msgSender() != ERC3525SlotEnumerableUpgradeable.getSlotSnapshot(slot_).originator) revert RegenerativeUtils.NotOriginator();
        _;
    }

    // todo: add value in slot when rwa owner transfer nft into erc3525
    // todo: need to verify the token data is the same as slot
    function addValueToSlot(uint256 slot_, uint256 rwaAmount_, uint256 tokenId_) external onlyOriginator(slot_) {
        if (!verifyAsset(tokenId_, slot_)) revert RegenerativeUtils.InvalidToken();
        IERC721(address(RegenerativeUtils.ASSET_NFT)).safeTransferFrom(_msgSender(), address(this), tokenId_);
        uint256 oldValue = slotTotalValue(slot_);
        _addValueToSlot(slot_, rwaAmount_, tokenId_);
        emit SlotValueChanged(slot_, oldValue, slotTotalValue(slot_));
    }

    function verifyAsset(uint256 tokenId_, uint256 slot_) internal returns (bool) {
        AssetChecker.TokenData memory tokenData = AssetChecker(RegenerativeUtils.ASSET_NFT).data(tokenId_);
        SlotData memory slotData = ERC3525SlotEnumerableUpgradeable.getSlotSnapshot(slot_);
        return (slotData.originator == tokenData.originator &&
            slotData.rwaValue == tokenData.assetValue &&
            slotData.maturity == tokenData.maturity);
    }

    // todo: remove value in slot when rwa owner withdraw nft from erc3525
    function removeValueFromSlot(uint256 slot_, uint256 rwaAmount_) external onlyOriginator(slot_) {
        uint256 oldValue = slotTotalValue(slot_);
        uint256 tokenId = _removeValueFromSlot(slot_, rwaAmount_);
        IERC721(address(RegenerativeUtils.ASSET_NFT)).safeTransferFrom(address(this), _msgSender(), tokenId);
        emit SlotValueChanged(slot_, oldValue, slotTotalValue(slot_));
    }

    function createSlot(
        address originator_,
        uint256 rwaValue_,
        uint256 minimumValue_,
        uint256 maturity_
    ) external onlyOwner {
        uint256 newSlot = _createSlot(
            originator_,
            rwaValue_,
            minimumValue_,
            maturity_
        );
        emit SlotValueChanged(newSlot, 0, 0);
    }

    function mint(uint256 slot_, uint256 value_) external {
        uint256 reHolding = IERC1155(RegenerativeUtils.RE_NFT).balanceOf(_msgSender(), 1);
        uint256 reStaking = IReStaking(RegenerativeUtils.RE_STAKE).nftBalance(_msgSender()).stakingAmount;
        uint256 fmHolding = IERC721(RegenerativeUtils.FREE_MINT).balanceOf(_msgSender());
        if (reHolding == 0 && reStaking == 0 && fmHolding == 0) revert RegenerativeUtils.NotQualified();
        
        if (!_slotExists(slot_)) revert RegenerativeUtils.InvalidSlot();
        SlotData memory slotData = ERC3525SlotEnumerableUpgradeable.getSlotSnapshot(slot_);
        if (slotData.mintableValue < value_) revert RegenerativeUtils.InsufficientBalance();
        if (value_ < slotData.minimumValue) revert RegenerativeUtils.BelowMinimumValue();

        if (ERC20(_currency).transferFrom(_msgSender(), RegenerativeUtils.MULTISIG, value_)) {
            _mintValue(_msgSender(), slot_, value_);
        }
    }

    function merge(uint256 tokenId_, uint256[] memory tokenIds_) external {
        if (ERC3525Upgradeable.ownerOf(tokenId_) != _msgSender()) revert RegenerativeUtils.NotOwner();
        
        uint256 length = tokenIds_.length;
        for (uint256 i = 0; i < length; i ++) {
            if (ERC3525Upgradeable.ownerOf(tokenIds_[i]) != _msgSender()) revert RegenerativeUtils.NotOwner();
        }
        _claim(tokenIds_, Operation.Merge);
        _merge(tokenId_, length, tokenIds_);
    }

    /**
     * split functions
     */
    function split(uint256 tokenId_, uint256 value_, uint256[] memory values_) external {
        if (_msgSender() != ownerOf(tokenId_)) revert RegenerativeUtils.NotOwner();

        uint256 balance = ERC3525Upgradeable.balanceOf(tokenId_);
        uint256 length = values_.length;
        uint256 value = value_;
        for (uint256 i = 0; i < length; i++) {
            value += values_[i];
        }
        if (balance - value != 0) revert RegenerativeUtils.MismatchValue(balance, value);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId_;
        _claim(tokenIds, Operation.Split);
        _split(tokenId_, length, values_);
    }

    /**
     *  claim functions
     */
    function claim() external {
        if (block.timestamp < LOCK_TIME) revert RegenerativeUtils.NotClaimable();

        _claim(ERC3525Upgradeable._getOwnedTokens(_msgSender()), Operation.Claim);
    }

    function _claim(uint256[] memory tokenIds_, Operation operation_) internal {
        uint256 balance = 0;
        uint256 length = tokenIds_.length;
        uint256 currtime = block.timestamp;
        uint256[] memory values = new uint256[](length);
        uint256[] memory interests = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds_[i];
            TokenData memory tokenData = ERC3525Upgradeable.getTokenSnapshot(tokenId);
            values[i] = tokenData.balance;
            uint256 interest = RegenerativeUtils._calculateClaimableInterest(
                tokenData.balance,
                currtime - tokenData.claimTime,
                RegenerativeUtils.YieldType.BASE_YIELD
            );
            balance += interest;
            interests[i] = interest;
            ERC3525Upgradeable._setClaimTime(tokenId, currtime);
        }

        ERC20(_currency).transfer(_msgSender(), balance);

        emit Claim(_msgSender(), operation_, tokenIds_, values, interests);
    }

    /**
     *  redeem functions
     */
    function redeem(uint256[] memory tokenIds_) public {
        // _storeReStakeDurations(_msgSender());
        _redeem(tokenIds_, block.timestamp);
    }

    function redeem(uint256 tokenId_) external {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId_;
        redeem(tokenIds);
    }
    // test event
    event RedeemSnapshot(uint256 _tokenId, TokenData _tokendata);

    function _redeem(uint256[] memory tokenIds_, uint256 currtime_) internal {
        uint256 length = tokenIds_.length;
        uint256 principal = 0;
        uint256 baseYield = 0;
        uint256 bonusYield = 0;

        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds_[i];
            TokenData memory tokenData =  ERC3525Upgradeable.getTokenSnapshot(tokenId);
            if (maturityOf(tokenId) > currtime_) revert RegenerativeUtils.NotRedeemable();
            if (_msgSender() != ERC3525Upgradeable.ownerOf(tokenId)) revert RegenerativeUtils.NotOwner();

            principal += ERC3525Upgradeable.balanceOf(tokenId);
            baseYield += RegenerativeUtils._calculateClaimableInterest(
                tokenData.balance,
                currtime_ - tokenData.claimTime,
                RegenerativeUtils.YieldType.BASE_YIELD
            );
            
            uint256 bonusSecs = tokenData.highYieldSecs + _calculateHighYieldSecs(tokenId);
            bonusYield += RegenerativeUtils._calculateClaimableInterest(
                tokenData.balance,
                bonusSecs,
                RegenerativeUtils.YieldType.BONUS_YIELD
            );
            emit RedeemSnapshot(tokenId, ERC3525Upgradeable.getTokenSnapshot(tokenId));
            _burn(tokenId);
        }

        ERC20(_currency).transfer(
            _msgSender(),
            principal + baseYield + bonusYield
        );

        emit Redeem(_msgSender(), principal, baseYield + bonusYield);
    }

    // test event
    event StakeInfo(uint256, uint256);

    function _storeReStakeDurations(address staker) internal {
        uint256 start = _reStakingIndex[staker];
        for (uint256 i = start; i < 2**256 - 1; i++) {
            try IReStaking(RegenerativeUtils.RE_STAKE).stakingInfo(staker, i) returns (
                IReStaking.StakingInfo memory stakingInfo
            ) {
                emit StakeInfo(stakingInfo.staketime, stakingInfo.unstaketime);
                Duration memory duration = Duration({
                    start: uint64(stakingInfo.staketime),
                    end: 0
                });
                if (_reStakingDurations[staker].length == 0) {
                    _reStakingDurations[staker].push(duration);
                    emit UpdateDuration(
                        staker,
                        _reStakingIndex[staker],
                        duration.start,
                        duration.end
                    );
                } else {
                    uint256 lastIndex = _reStakingDurations[staker].length - 1;
                    Duration storage lastDuration = _reStakingDurations[staker][lastIndex];
                    if (!stakingInfo.isUnstake) {
                        if (i == 0) break;
                        if (duration.start < lastDuration.end &&
                            lastDuration.end != 0) {
                            lastDuration.end = duration.end;
                            emit UpdateDuration(
                                staker,
                                lastIndex,
                                lastDuration.start,
                                lastDuration.end
                            );
                        } else {
                            _reStakingDurations[staker].push(duration);
                            emit UpdateDuration(
                                staker,
                                _reStakingIndex[staker],
                                duration.start,
                                duration.end
                            );
                            break;
                        }
                    } else {
                        duration.end = uint64(stakingInfo.unstaketime);

                        if (lastDuration.end > duration.start ||
                            lastDuration.end == 0) {
                            lastDuration.end = duration.end;
                            emit UpdateDuration(
                                staker,
                                lastIndex,
                                lastDuration.start,
                                lastDuration.end
                            );
                        } else if (lastDuration.end < duration.start &&
                            lastDuration.end != 0) {
                            _reStakingDurations[staker].push(duration);
                            emit UpdateDuration(
                                staker,
                                _reStakingIndex[staker],
                                duration.start,
                                duration.end
                            );
                        } else if (lastDuration.start == duration.start) {
                            lastDuration.end = duration.end;
                            emit UpdateDuration(
                                staker,
                                lastIndex,
                                lastDuration.start,
                                lastDuration.end
                            );
                        }
                        _reStakingIndex[staker]++;
                    }
                }
            } catch (bytes memory reason) {
                reason;
                break;
            }
        }
    }

    function getClaimableInterest(address owner_) external returns (uint256) {
        uint256 interest = 0;
        uint256[] memory tokenIds = ERC3525Upgradeable._getOwnedTokens(owner_);
        uint256 length = ERC3525Upgradeable.balanceOf(owner_);
        uint256 currtime = block.timestamp;
        for (uint256 i = 0; i < length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 claimtime = ERC3525Upgradeable.getTokenSnapshot(tokenId).claimTime;
            interest += RegenerativeUtils._calculateClaimableInterest(
                ERC3525Upgradeable.balanceOf(tokenId), 
                currtime - claimtime,
                RegenerativeUtils.YieldType.BASE_YIELD
            );
        }
        return interest;
    }

    function _calculateHighYieldSecs(uint256 tokenId_)
        internal
        view
        returns (uint256)
    {
        uint256 highYieldSecs = 0;

        uint256 transfertime = ERC3525Upgradeable.getTokenSnapshot(tokenId_).transferTime;

        uint256 length = _reStakingDurations[msg.sender].length;
        for (uint256 i = 0; i < length; i++) {
            Duration memory reStakingDuration = _reStakingDurations[msg.sender][i];
            // this Re staking duration is prior to
            // the transfertime of token id
            if (reStakingDuration.end != 0 && reStakingDuration.end <= transfertime) continue;
            uint256 start = reStakingDuration.start <= transfertime ? transfertime : reStakingDuration.start;
            uint256 end = reStakingDuration.end > 0 ? reStakingDuration.end : block.timestamp;
            uint256 duration = end - start;
            highYieldSecs += duration;
        }
        return highYieldSecs;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}

    // override
    // needs to update the Re staking durations before token Id transfer
    function _transferTokenId(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal virtual override {
        RegenerativeNFT._storeReStakeDurations(from_);
        super._transferTokenId(from_, to_, tokenId_);
    }

    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual override {
        super._beforeValueTransfer(from_, to_, fromTokenId_, toTokenId_, slot_, value_);
        if (fromTokenId_ == toTokenId_ && from_ != to_) {
            // transfer token to to_
            ERC3525Upgradeable._updateHighYieldSecsByTokenId(
                fromTokenId_,
                _calculateHighYieldSecs(fromTokenId_)
            );
            ERC3525Upgradeable._updateTransferTimeByTokenId(fromTokenId_);
        } else if (from_ == to_ && ERC3525Upgradeable.balanceOf(toTokenId_) != 0) {
            // merge
            ERC3525Upgradeable._updateHighYieldSecsByTokenId(
                fromTokenId_,
                _calculateHighYieldSecs(fromTokenId_)
            );
        }
    }
}
