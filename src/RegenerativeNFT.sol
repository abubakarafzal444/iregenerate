// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC3525/ERC3525SlotEnumerable.sol";
import "./IRegenerative.sol";
import "./Constants.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";

contract RegenerativeNFT is
    Ownable,
    UUPSUpgradeable,
    Initializable,
    ERC3525SlotEnumerable,
    IRegenerative
{
    address public RegenerativePool;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external initializable {
        ERC3525Upgradeable.__ERC3525_init(name_, symbol_, decimals_);
    }

    function setRegenerativePool(address addr_) external onlyOwner {
        RegenerativePool = addr_;
    }

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
        uint256 removedValue = rwaAmount_ *
            _allSlots[_allSlotsIndex[slot_]].rwaValue;
        uint256 balance = balanceInSlot(slot_);

        if (removedValue > balance) revert Constants.InsufficientBalance();
        if (rwaAmount_ > _allSlots[_allSlotsIndex[slot_]].rwaAmount)
            revert Constants.ExceedUnits();

        _allSlots[_allSlotsIndex[slot_]].rwaAmount -= rwaAmount_;
        _allSlots[_allSlotsIndex[slot_]].mintableValue -= removedValue;
    }

    function createSlot(
        uint256 rwaAmount_,
        uint256 rwaValue_,
        uint256 minimumValue_,
        address currency_
    ) external onlyOwner {
        uint256 slotId = slotCount() + 1;
        SlotData memory slotData = SlotData({
            slot: slotId,
            slotTokens: new uint256[](0),
            minimumValue: minimumValue,
            mintableValue: rwaAmount_ * rwaValue_,
            rwaValue: rwaValue_,
            rwaAmount: rwaAmount_,
            currency: currency_
        });
        _addSlotToAllSlotsEnumeration(slotData);
    }

    function highYieldSecsOf(uint256 tokenId_) public view returns (uint256) {
        require(
            _exists(tokenId_),
            "ERC3525: balance query for nonexistent token"
        );
        return _allTokens[_allTokensIndex[tokenId_]].highYieldSecs;
    }

    function mint(
        address currency_,
        uint256 slot_,
        uint256 value_
    ) external {
        // uint256 reHolding = OwnerChecker(Constants.RE_NFT).balanceOf(msg.sender);
        // uint256 reStaking = OwnerChecker(Constants.RE_STAKE)
        //     .nftBalance(msg.sender)
        //     .stakingAmount;
        // uint256 fmHolding = OwnerChecker(Constants.FREE_MINT).balanceOf(msg.sender);
        // if (reHolding == 0 && reStaking == 0 && fmHolding == 0)
        //     revert Constants.NotQualified();

        if (!_slotExists(slot_)) revert Constants.InvalidSlot();
        if (balanceInSlot(slot_) < value_) revert Constants.ExceedTVL();

        SlotData memory slotData = _allSlots[_allSlotsIndex[slot_]];
        if (value_ < slotData.minimumValue)
            revert Constants.InsufficientBalance();

        if (IERC20(Constants.USDC).transferFrom(msg.sender, MULTISIG, value_)) {
            _mintValue(msg.sender, slot_, totalValue);
        }
    }

    function merge(uint256[] calldata tokenIds_) external {
        uint256 length = tokenIds_.length;
        uint256 claimableYield = 0;
        uint256 highYieldSecs = 0;
        TokenData storage targetTokenData = _allTokens[
            _allTokensIndex[tokenIds_[0]]
        ];
        if (msg.sender != targetTokenData.owner) revert Constants.NotOwner();
        uint256 maturity = targetTokenData.maturity;
        for (uint256 i = 1; i < length; i++) {
            if (msg.sender != ownerOf(tokenIds_[i]))
                revert Constants.NotOwner();
            TokenData memory sourceTokenData = _allTokens[
                _allTokensIndex[tokenIds_[i]]
            ];
            _transferValue(tokenIds_[i], tokenIds_[0], sourceTokenData.balance);
            claimableYield += sourceTokenData.claimableYield;
            highYieldSecs += sourceTokenData.highYieldSecs;
            if (maturity < sourceTokenData.maturity) {
                maturity = sourceTokenData.maturity;
            }
            _burn(tokenIds_[i]);
        }
        targetTokenData.maturity = maturity;
        targetTokenData.claimableYield += claimableYield;
        targetTokenData.highYieldSecs += highYieldSecs;
    }

    modifier onlyPool() {
        if (msg.sender != RegenerativePool) revert Constants.OnlyStake();
        _;
    }

    function burn(uint256 tokenId_) external onlyPool {
        _burn(tokenId_);
    }

    function updateStakeDataByTokenId(
        uint256 tokenId_,
        uint256 secs_
    ) external onlyPool {
        _allTokens[_allTokensIndex[tokenId_]].highYieldSecs += secs;
    }

    function removeStakeDataByTokenId(uint256 tokenId_) external onlyPool {
        delete _allTokens[_allTokensIndex[tokenId_]].highYieldSecs;
    }

    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        _spendAllowance(_msgSender(), fromTokenId_, value_);
        uint256 newTokenId = _createDerivedTokenId(fromTokenId_);
        _mint(to_, newTokenId, slotOf(fromTokenId_));
        _transferValue(fromTokenId_, newTokenId, value_);
        return newTokenId;
    }

    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        _spendAllowance(_msgSender(), fromTokenId_, value_);
        address from_ = _allTokens[_allTokensIndex[fromTokenId_]].owner;
        address to_ = _allTokens[_allTokensIndex[toTokenId_]].owner;
        _transferValue(fromTokenId_, toTokenId_, value_);
    }

    function getSlotSnapShotByTokenId(uint256 tokenId_) external view returns(SlotData memory) {

    }

    function _authorizeUpgrade(address newImplementation)
        internal
        virtual
        override
        onlyOwner
    {}
}
