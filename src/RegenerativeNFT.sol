// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC3525/ERC3525SlotEnumerableUpgradeable.sol";
import "./IRegenerative.sol";
import "./Constants.sol";
import "openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";

contract RegenerativeNFT is
    OwnableUpgradeable,
    UUPSUpgradeable,
    ERC3525SlotEnumerableUpgradeable,
    IRegenerative
{
    address public RegenerativePool;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external initializer {
        ERC3525Upgradeable.__ERC3525_init(name_, symbol_, decimals_);
        OwnableUpgradeable.__Ownable_init();
    }

    function setRegenerativePool(address addr_) external onlyOwner {
        RegenerativePool = addr_;
    }

    modifier onlyPool() {
        if (msg.sender != RegenerativePool) revert Constants.OnlyPool();
        _;
    }

    function maturityOf(uint256 tokenId_) external view returns (uint256) {
        return getTokenSnapshot(tokenId_).mintTime + 
            getSlotSnapshot(slotOf(tokenId_)).maturity;
    }

    function balanceInSlot(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        return getSlotSnapshot(slot_).mintableValue;
    }

    function slotTotalValue(uint256 slot_) public view returns (uint256) {
        if (!_slotExists(slot_)) return 0;
        SlotData memory slotdata = getSlotSnapshot(slot_);
        return slotdata.rwaValue * slotdata.rwaAmount;
    }

    function addValueInSlot(uint256 slot_, uint256 rwaAmount_)
        external
        onlyOwner
    {
        uint256 oldValue = slotTotalValue(slot_);
        _addValueInSlot(slot_, rwaAmount_);
        emit SlotValueChanged(slot_, oldValue, slotTotalValue(slot_));
    }

    function removeValueInSlot(uint256 slot_, uint256 rwaAmount_)
        external
        onlyOwner
    {
        uint256 oldValue = slotTotalValue(slot_);
        _removeValueInSlot(slot_, rwaAmount_);
        emit SlotValueChanged(slot_, oldValue, slotTotalValue(slot_));
    }

    function createSlot(
        uint256 rwaAmount_,
        uint256 rwaValue_,
        uint256 minimumValue_,
        address currency_,
        uint256 maturity_
    ) external onlyOwner {
        _createSlot(rwaAmount_, rwaValue_, minimumValue_, currency_, maturity_);
    }

    function highYieldSecsOf(uint256 tokenId_) public view returns (uint256) {
        require(
            _exists(tokenId_),
            "ERC3525: balance query for nonexistent token"
        );
        return ERC3525Upgradeable.getTokenSnapshot(tokenId_).highYieldSecs;
    }

    function mint(uint256 slot_, uint256 value_) external {
        // uint256 reHolding = OwnerChecker(Constants.RE_NFT).balanceOf(msg.sender);
        // uint256 reStaking = OwnerChecker(Constants.RE_STAKE)
        //     .nftBalance(msg.sender)
        //     .stakingAmount;
        // uint256 fmHolding = OwnerChecker(Constants.FREE_MINT).balanceOf(msg.sender);
        // if (reHolding == 0 && reStaking == 0 && fmHolding == 0)
        //     revert Constants.NotQualified();

        if (!_slotExists(slot_)) revert Constants.InvalidSlot();
        SlotData memory slotData = getSlotSnapshot(slot_);
        if (slotData.mintableValue < value_) revert Constants.ExceedTVL();
        if (value_ < slotData.minimumValue)
            revert Constants.InsufficientBalance();

        if (
            Constants.transferCurrencyTo(msg.sender, slotData.currency, value_, ERC3525Upgradeable.valueDecimals())
        ) {
            _mintValue(msg.sender, slot_, value_);
        }
    }

    function merge(uint256[] calldata tokenIds_) external {
        _merge(tokenIds_);
    }

    function split(uint256 tokenId_, uint256[] calldata values_) external {
        if (msg.sender != ownerOf(tokenId_)) revert Constants.NotOwner();
        uint256 balance = balanceOf(tokenId_);
        uint256 length = values_.length;
        for (uint256 i = 0; i < length; i++) {
            balance -= values_[i];
        }
        if (balance != 0) revert Constants.MismatchValue();
        _split(tokenId_, length, values_);

    }

    function burn(uint256 tokenId_) external onlyPool {
        _burn(tokenId_);
    }

    function updateStakeDataByTokenId(uint256 tokenId_, uint256 secs_)
        external
        onlyPool
    {
        _updateStakeDataByTokenId(tokenId_, secs_);
    }

    function removeStakeDataByTokenId(uint256 tokenId_) external onlyPool {
        _removeStakeDataByTokenId(tokenId_);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}
