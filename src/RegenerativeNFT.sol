// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC3525/ERC3525SlotEnumerable.sol";
import "./IRegenerative.sol";
import "./Constants.sol";
import "openzeppelin-contracts/access/Ownable.sol";

contract RegenerativeNFT is ERC3525SlotEnumerable, IRegenerative, Ownable {
    address public RegenerativeStake;

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) external {
        ERC3525Upgradeable.__ERC3525_init(name_, symbol_, decimals_);
    }

    function setRegenerativeStake(address addr_) external onlyOwner {
        RegenerativeStake = addr_;
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

    function highYieldSecsOf(uint256 tokenId_) public view returns (uint256) {
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
        if (!_slotExists(slot_)) revert Constants.InvalidSlot();
        if (balanceInSlot(slot_) < value_) revert Constants.ExceedTVL();
        if (IERC20(USDC).transferFrom(msg.sender, MULTISIG, value_)) {
            _mintValue(msg.sender, slot_, value_);
        }
    }

    function merge(uint256[] calldata tokenIds_, uint256 highYieldSecs_)
        external
    {
        uint256 length = tokenIds_.length;
        TokenData storage tokenData = _allTokens[_allTokensIndex[tokenIds_[0]]];
        if (msg.sender != tokenData.owner) revert Constants.NotOwner();
        uint256 redemption = tokenData.redemption;
        for (uint256 i = 1; i < length; i++) {
            if (msg.sender != _allTokens[_allTokensIndex[tokenIds_[i]]].owner) {
                revert Constants.NotOwner();
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

    modifier onlyStake() {
        if (msg.sender != RegenerativeStake) revert Constants.OnlyStake();
        _;
    }

    function burn(uint256 tokenId_) external onlyStake {
        _burn(tokenId_);
    }

    function updateHighYieldSecsByTokenId(uint256 tokenId_, uint256 secs_)
        external
        onlyStake
    {
        if (secs_ == 0) {
            _allTokens[_allTokensIndex[tokenId_]].highYieldSecs = secs;
        } else {
            _allTokens[_allTokensIndex[tokenId_]].highYieldSecs += secs;
        }
    }

    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        _spendAllowance(_msgSender(), fromTokenId_, value_);
        uint256 newTokenId = _createDerivedTokenId(fromTokenId_);
        // to_ need to transfer ERC20 value_ to msg.sender
        // ERC 3525 would mint a new NFT with value_ to to_
        _mint(to_, newTokenId, slotOf(fromTokenId_));
        _transferValue(fromTokenId_, newTokenId, value_);
        if (to_ != RegenerativeStake) {
            IERC20(Constants.USDC).transferFrom(to_, msg.sender, value_);
        }
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

        TokenData memory fromTokenData = _allTokens[
            _allTokensIndex[fromTokenId_]
        ];
        TokenData memory toTokenData = _allTokens[_allTokensIndex[toTokenId_]];

        if (fromTokenData.owner != toTokenData.owner) {
            // to_ needs to transfer ERC20 value_ to from_
            // from_ will transfer value_ from fromTokenId_ to toTokenId_
            IERC20(Constants.USDC).transferFrom(to_, from_, value_);
        }
        _transferValue(fromTokenId_, toTokenId_, value_);
    }
}
