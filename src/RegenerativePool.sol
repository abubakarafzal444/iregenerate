// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC3525/IERC3525.sol";
import "./ERC3525/ERC3525Holder.sol";
import "./IReStaking.sol";
import "./IRegenerative.sol";
import "./IRegenerativePool.sol";
import "./RegenerativeCore.sol";
import "./Constants.sol";
import "openzeppelin-contracts/token/ERC721/utils/ERC721Holder.sol";
import "openzeppelin-contracts/interfaces/IERC20.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/proxy/utils/UUPSUpgradeable.sol";
import "openzeppelin-contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/utils/introspection/ERC165.sol";

contract RegenerativePool is
    Ownable,
    UUPSUpgradeable,
    Initializable,
    ERC165,
    RegenerativeCore,
    ERC721Holder,
    ERC3525Holder,
    IRegenerativePool
{
    uint256 public LOCK_TIME;

    function initialize(address ierc3525_, uint256 locktime_, address currency_, uint256[] memory slots_)
        public
        initializer
    {
        erc3525 = IERC3525(ierc3525_);
        iregenerative = IRegenerative(ierc3525_);
        LOCK_TIME = locktime_;
        currency = currency_;
        uint256 length = slots_.length;
        for (uint i = 0; i < length; i++) {
            slots[slots_[i]] = true;
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IRegenerative).interfaceId ||
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC3525Receiver).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function balanceOf(address owner_) external view returns (uint256) {
        return _stakingRecords[owner_].length;
    }

    /**
     *  stake functions
     *  the decimals of value_ is valueDecimals_
     */
    function stake(uint256[] memory tokenIds_, uint256[] memory values_) public {
        uint256 length = tokenIds_.length;

        if (length != values_.length) revert Constants.ListMismatch();
        
        for (uint256 i = 0; i < length; i++) {
            if (msg.sender != erc3525.ownerOf(tokenIds_[i])) revert Constants.NotOwner();
            if (values_[i] == 0) revert Constants.InvalidValue();
            _stake(tokenIds_[i], values_[i]);
        }
    }

    function stake(uint256 tokenId_, uint256 value_) external {
        uint256[] memory tokenIds = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        tokenIds[0] = tokenId_;
        values[0] = value_;
        stake(tokenIds, values);
    }

    /**
        claim related functions
     */
    function claim() external {
        if (block.timestamp < LOCK_TIME) revert Constants.NotClaimable();

        _claim(_stakingRecords[msg.sender], uint64(block.timestamp));
    }

    /**
        unstake functions
     */
    function unstake(uint256[] memory tokenIds_) public {
        _storeReStakeDurations(msg.sender);
        _unstake(tokenIds_, uint64(block.timestamp));
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
