// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525Upgradeable.sol";
import "./extensions/IERC3525SlotEnumerable.sol";

contract ERC3525SlotEnumerableUpgradeable is
    ERC3525Upgradeable,
    IERC3525SlotEnumerable
{
    struct SlotData {
        uint256 slot;
        uint256[] slotTokens;
        uint256 minimumValue;
        uint256 mintableValue;
        uint256 rwaValue;
        uint256 rwaAmount;
        address currency;
    }
    // slot => tokenId => index
    mapping(uint256 => mapping(uint256 => uint256)) private _slotTokensIndex;

    SlotData[] private _allSlots;

    // slot => index
    mapping(uint256 => uint256) private _allSlotsIndex;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC3525Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC3525SlotEnumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function slotCount() public view virtual override returns (uint256) {
        return _allSlots.length;
    }

    function getSlotSnapshot(uint256 slot_)
        public
        view
        returns (SlotData memory)
    {
        return _allSlots[_allSlotsIndex[slot_]];
    }

    function slotByIndex(uint256 index_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index_ < ERC3525SlotEnumerableUpgradeable.slotCount(),
            "ERC3525SlotEnumerable: slot index out of bounds"
        );
        return _allSlots[index_].slot;
    }

    function _slotExists(uint256 slot_) internal view virtual returns (bool) {
        return
            _allSlots.length != 0 &&
            _allSlots[_allSlotsIndex[slot_]].slot == slot_;
    }

    function _addValueInSlot(uint256 slot_, uint256 rwaAmount_) internal {
        _allSlots[_allSlotsIndex[slot_]].rwaAmount += rwaAmount_;
        uint256 addedValue = rwaAmount_ *
            _allSlots[_allSlotsIndex[slot_]].rwaValue;
        _allSlots[_allSlotsIndex[slot_]].mintableValue += addedValue;
    }

    function _removeValueInSlot(uint256 slot_, uint256 rwaAmount_) internal {
        uint256 removedValue = rwaAmount_ *
            _allSlots[_allSlotsIndex[slot_]].rwaValue;
        uint256 balance = _allSlots[_allSlotsIndex[slot_]].mintableValue;

        if (removedValue > balance) revert Constants.InsufficientBalance();
        if (rwaAmount_ > _allSlots[_allSlotsIndex[slot_]].rwaAmount)
            revert Constants.ExceedUnits();

        _allSlots[_allSlotsIndex[slot_]].rwaAmount -= rwaAmount_;
        _allSlots[_allSlotsIndex[slot_]].mintableValue -= removedValue;
    }

    function _createSlot(
        uint256 rwaAmount_,
        uint256 rwaValue_,
        uint256 minimumValue_,
        address currency_
    ) internal {
        uint256 slotId = slotCount() + 1;
        SlotData memory slotData = SlotData({
            slot: slotId,
            slotTokens: new uint256[](0),
            minimumValue: minimumValue_,
            mintableValue: rwaAmount_ * rwaValue_,
            rwaValue: rwaValue_,
            rwaAmount: rwaAmount_,
            currency: currency_
        });
        _addSlotToAllSlotsEnumeration(slotData);
    }

    function tokenSupplyInSlot(uint256 slot_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (!_slotExists(slot_)) {
            return 0;
        }
        return _allSlots[_allSlotsIndex[slot_]].slotTokens.length;
    }

    function tokenInSlotByIndex(uint256 slot_, uint256 index_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            index_ < ERC3525SlotEnumerableUpgradeable.tokenSupplyInSlot(slot_),
            "ERC3525SlotEnumerable: slot token index out of bounds"
        );
        return _allSlots[_allSlotsIndex[slot_]].slotTokens[index_];
    }

    function _tokenExistsInSlot(uint256 slot_, uint256 tokenId_)
        private
        view
        returns (bool)
    {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        return
            slotData.slotTokens.length > 0 &&
            slotData.slotTokens[_slotTokensIndex[slot_][tokenId_]] == tokenId_;
    }

    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual override {
        //Shh - currently unused
        from_;
        fromTokenId_;
        to_;
        toTokenId_;
        slot_;
        value_;
    }

    function _afterValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual override {
        if (
            from_ == address(0) &&
            fromTokenId_ == 0 &&
            !_tokenExistsInSlot(slot_, toTokenId_)
        ) {
            _addTokenToSlotEnumeration(slot_, toTokenId_);
            _allSlots[_allSlotsIndex[slot_]].mintableValue -= value_;
        } else if (
            to_ == address(0) &&
            toTokenId_ == 0 &&
            _tokenExistsInSlot(slot_, fromTokenId_)
        ) {
            _removeTokenFromSlotEnumeration(slot_, fromTokenId_);
            _allSlots[_allSlotsIndex[slot_]].mintableValue += value_;
        }
    }

    function _addSlotToAllSlotsEnumeration(SlotData memory slotData) private {
        _allSlotsIndex[slotData.slot] = _allSlots.length;
        _allSlots.push(slotData);
    }

    function _addTokenToSlotEnumeration(uint256 slot_, uint256 tokenId_)
        private
    {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        _slotTokensIndex[slot_][tokenId_] = slotData.slotTokens.length;
        slotData.slotTokens.push(tokenId_);
    }

    function _removeTokenFromSlotEnumeration(uint256 slot_, uint256 tokenId_)
        private
    {
        SlotData storage slotData = _allSlots[_allSlotsIndex[slot_]];
        uint256 lastTokenIndex = slotData.slotTokens.length - 1;
        uint256 lastTokenId = slotData.slotTokens[lastTokenIndex];
        uint256 tokenIndex = slotData.slotTokens[tokenId_];

        slotData.slotTokens[tokenIndex] = lastTokenId;
        _slotTokensIndex[slot_][lastTokenId] = tokenIndex;

        delete _slotTokensIndex[slot_][tokenId_];
        slotData.slotTokens.pop();
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[47] private __gap;
}