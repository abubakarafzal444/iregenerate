// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./ERC3525SlotEnumerable.sol";
import "./IRegenerative.sol";

error NotQualified();
error InvalidSlot();
error ExceedTVL();
error NotOwner();
error OnlyStake();

contract RegenerativeNFT is ERC3525SlotEnumerable, IRegenerative {
    address public RegenerativeStake = address(0);

    function balanceInSlot(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        return _allSlots[_allSlotsIndex[slot_]].mintableValue;
    }

    function slotTotalValue(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        return
            _allSlots[_allSlotsIndex[slot_]].rwaValue *
            _allSlots[_allSlotsIndex[slot_]].rwaAmount;
    }

    function addValueInSlot(uint256 slot_, uint256 rwaAmount_)
        external
        onlyOwner
    {
        _allSlots[_allSlotsIndex[slot_]].rwaAmount += rwaAmount_;
        uint256 addedValue = rwaAmount_ *
            _allSlots[_allSlotsIndex[slot_]].rwaValue;
        _allSlots[_allSlotsIndex[slot_]].mintableValue += addedValue;
    }

    function removeValueInSlot(uint256 slot_, uint256 rwaAmount_)
        external
        onlyOwner
    {
        _allSlots[_allSlotsIndex[slot_]].rwaAmount -= rwaAmount_;
        uint256 removedValue = rwaAmount_ *
            _allSlots[_allSlotsIndex[slot_]].rwaValue;
        _allSlots[_allSlotsIndex[slot_]].mintableValue -= removedValue;
    }

    function createSlot(uint256 rwaAmount_, uint256 rwaValue_)
        external
        onlyOwner
    {
        uint256 slotId = slotCount() + 1;
        SlotData memory slotData = SlotData({
            slot: slotId,
            slotTokens: new uint256[](0),
            mintableValue: rwaAmount_ * rwaValue_,
            rwaValue: rwaValue_,
            rwaAmount: rwaAmount_
        });
        _addSlotToAllSlotsEnumeration(slotData);
    }

    function highYieldSecsOf(uint256 tokenId_)
        public
        view
        returns (uint256)
    {
        require(
            _exists(tokenId_),
            "ERC3525: balance query for nonexistent token"
        );
        return _allTokens[_allTokensIndex[tokenId_]].highYieldSecs;
    }

    function mint(uint256 slot_, uint256 value_) external {
        uint256 reHolding = OwnerChecker(RE_NFT).balanceOf(msg.sender);
        uint256 reStaking = OwnerChecker(RE_STAKE)
            .nftBalance(msg.sender)
            .stakingAmount;
        uint256 fmHolding = OwnerChecker(FREE_MINT).balanceOf(msg.sender);
        if (reHolding == 0 && reStaking == 0 && fmHolding == 0)
            revert NotQualified();
        if (!_slotExists(slot_)) revert InvalidSlot();
        if (balanceInSlot(slot_) < value_) revert ExceedTVL();
        if (IERC20(USDC).transferFrom(msg.sender, MULTISIG, value_)) {
            _mintValue(msg.sender, slot_, value_);
        }
    }

    function merge(uint256[] calldata tokenIds_, uint256 highYieldSecs_)
        external
    {
        uint256 length = tokenIds_.length;
        TokenData storage tokenData = _allTokens[_allTokensIndex[tokenIds_[0]]];
        if (msg.sender != tokenData.owner) revert NotOwner();
        uint256 redemption = tokenData.redemption;
        for (uint256 i = 1; i < length; i++) {
            if (msg.sender != _allTokens[_allTokensIndex[tokenIds_[i]]].owner) {
                revert NotOwner();
            }
            _transferValue(
                tokenIds_[0],
                tokenIds_[i],
                _allTokens[_allTokensIndex[tokenIds_[i]]].balance
            );
            uint256 burnRedemption = _allTokens[_allTokensIndex[tokenIds_[i]]]
                .redemption;
            if (redemption < burnRedemption) {
                redemption = burnRedemption;
            }
            _burn(tokenIds_[i]);
        }
        tokenData.redemption = redemption;
        tokenData.highYieldSecs = highYieldSecs_;
    }

    modifier onlyStake {
        if (msg.sender != RegenerativeStake) revert OnlyStake();
        _;
    }

    function burn(uint256 tokenId_) external onlyStake {
        _burn(tokenId_);
    }

    function updateHighYieldSecsByTokenId(uint256 tokenId_, uint256 secs_)
        external onlyStake
    {
        if (secs_ == 0) {
            _allTokens[_allTokensIndex[tokenId_]].highYieldSecs = secs;
        } else {
            _allTokens[_allTokensIndex[tokenId_]].highYieldSecs += secs;
        }
    }
}
