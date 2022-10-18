// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/interfaces/IERC721.sol";
import "openzeppelin-contracts/interfaces/IERC721Enumerable.sol";
import "openzeppelin-contracts/interfaces/IERC721Receiver.sol";
import "openzeppelin-contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/ContextUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts/utils/Strings.sol";
import "./IERC3525.sol";
import "./IERC3525Receiver.sol";
import "./extensions/IERC3525Metadata.sol";
import "./periphery/interface/IERC3525MetadataDescriptor.sol";
import "./utils/StringConvertor.sol";

abstract contract ERC3525Upgradeable is
    IERC3525Metadata,
    IERC721Enumerable,
    ERC165Upgradeable,
    ContextUpgradeable
{
    using Strings for address;
    using AddressUpgradeable for address;
    using StringConvertor for uint256;

    event SetMetadataDescriptor(address indexed metadataDescriptor);

    /**
     * @dev MUST emit when multiple tokens with the same slot is merged into one token
     * @param _owner The tokens owner
     * @param _tokenId The tokenId
     * @param _value The total value of merged token
     */
    event Merge(address indexed _owner, uint256 _tokenId, uint256 _value);

    struct TokenData {
        uint256 id;
        uint256 slot;
        address owner;
        address approved;
        address[] valueApprovals;
        uint256 balance;
        uint256 mintTime;
        uint256 transferTime;
        uint256 claimTime;
        uint256 highYieldSecs;
    }

    struct AddressData {
        uint256[] ownedTokens;
        mapping(uint256 => uint256) ownedTokensIndex;
        mapping(address => bool) approvals;
    }

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // id => (approval => allowance)
    // @dev _approvedValues can not be defined within TokenData, cause struct containing mappings cannot be constructed.
    mapping(uint256 => mapping(address => uint256)) private _approvedValues;

    TokenData[] private _allTokens;

    //key: id
    mapping(uint256 => uint256) private _allTokensIndex;

    mapping(address => AddressData) private _addressData;

    IERC3525MetadataDescriptor public metadataDescriptor;

    mapping(uint256 => bool) private _derivedTokenId;

    // solhint-disable-next-line
    function __ERC3525_init(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) internal onlyInitializing {
        __ERC3525_init_unchained(name_, symbol_, decimals_);
    }

    // solhint-disable-next-line
    function __ERC3525_init_unchained(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) internal onlyInitializing {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IERC3525).interfaceId ||
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC3525Metadata).interfaceId ||
            interfaceId == type(IERC721Enumerable).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the token collection name.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token collection symbol.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals the token uses for value.
     */
    function valueDecimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function balanceOf(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(_exists(tokenId_), "ERC3525: balance query for nonexistent token");
        return _allTokens[_allTokensIndex[tokenId_]].balance;
    }

    // ERC721 Compatible
    function ownerOf(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (address owner_)
    {
        require(_exists(tokenId_), "ERC3525: owner query for nonexistent token");
        owner_ = _allTokens[_allTokensIndex[tokenId_]].owner;
        require(owner_ != address(0), "ERC3525: owner query for nonexistent token");
    }

    function slotOf(uint256 tokenId_)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(_exists(tokenId_), "ERC3525: slot query for nonexistent token");
        return _allTokens[_allTokensIndex[tokenId_]].slot;
    }

    function _baseURI() internal view virtual returns (string memory) {
        return "";
    }

    function contractURI() public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return 
            address(metadataDescriptor) != address(0) ? 
                metadataDescriptor.constructContractURI() :
                bytes(baseURI).length > 0 ? 
                    string(abi.encodePacked(baseURI, "contract/", Strings.toHexString(address(this)))) : 
                    "";
    }

    function slotURI(uint256 slot_) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return 
            address(metadataDescriptor) != address(0) ? 
                metadataDescriptor.constructSlotURI(slot_) : 
                bytes(baseURI).length > 0 ? 
                    string(abi.encodePacked(baseURI, "slot/", slot_.toString())) : 
                    "";
    }

    /**
     * @dev Returns the Uniform Resource Identifier (URI) for `tokenId` token.
     */
    function tokenURI(uint256 tokenId_) public view virtual override returns (string memory) {
        string memory baseURI = _baseURI();
        return 
            address(metadataDescriptor) != address(0) ? 
                metadataDescriptor.constructTokenURI(tokenId_) : 
                bytes(baseURI).length > 0 ? 
                    string(abi.encodePacked(baseURI, tokenId_.toString())) : 
                    "";
    }

    /**
     * @notice Custom function to get snapshot of token data
     * @param tokenId_ The token id of the token data
     */
    function getTokenSnapshot(uint256 tokenId_) public view returns (TokenData memory) {
        require(_exists(tokenId_), "ERC3525: snapshot query for nonexistent token");
        return _allTokens[_allTokensIndex[tokenId_]];
    }

    function approve(uint256 tokenId_, address to_, uint256 value_) public payable virtual override {
        address owner = ERC3525Upgradeable.ownerOf(tokenId_);
        require(to_ != owner, "ERC3525: approval to current owner");

        require(
            _msgSender() == owner || ERC3525Upgradeable.isApprovedForAll(owner, _msgSender()),
            "ERC3525: approve caller is not owner nor approved for all"
        );

        _approveValue(tokenId_, to_, value_);
    }

    function allowance(uint256 tokenId_, address operator_) public view virtual override returns (uint256) {
        return _approvedValues[tokenId_][operator_];
    }

    // todo: check if tokenData loss some info
    // transfer value to to_, new token should be inherited all time info from fromTokenId_
    function transferFrom(
        uint256 fromTokenId_,
        address to_,
        uint256 value_
    ) public payable virtual override returns (uint256) {
        _spendAllowance(_msgSender(), fromTokenId_, value_);

        uint256 newTokenId = _createDerivedTokenId(fromTokenId_);
        _mint(to_, newTokenId, ERC3525Upgradeable.slotOf(fromTokenId_));
        _transferValue(fromTokenId_, newTokenId, value_);

        return newTokenId;
    }

    function transferFrom(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) public payable virtual override {
        _spendAllowance(_msgSender(), fromTokenId_, value_);

        _transferValue(fromTokenId_, toTokenId_, value_);
    }

    function balanceOf(address owner_) public view virtual override returns (uint256 balance) {
        require(owner_ != address(0),"ERC3525: balance query for the zero address");
        return _addressData[owner_].ownedTokens.length;
    }

    function transferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC3525: transfer caller is not owner nor approved");

        _transferTokenId(from_, to_, tokenId_);
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId_), "ERC3525: transfer caller is not owner nor approved");
        _safeTransferTokenId(from_, to_, tokenId_, data_);
    }

    function safeTransferFrom(
        address from_,
        address to_,
        uint256 tokenId_
    ) public virtual override {
        safeTransferFrom(from_, to_, tokenId_, "");
    }

    function approve(address to_, uint256 tokenId_) public virtual override {
        address owner = ERC3525Upgradeable.ownerOf(tokenId_);
        require(to_ != owner, "ERC3525: approval to current owner");

        require(
            _msgSender() == owner || ERC3525Upgradeable.isApprovedForAll(owner, _msgSender()),
            "ERC3525: approve caller is not owner nor approved for all"
        );

        _approve(to_, tokenId_);
    }

    function getApproved(uint256 tokenId_) public view virtual override returns (address) {
        require(_exists(tokenId_), "ERC3525: approved query for nonexistent token");

        return _allTokens[_allTokensIndex[tokenId_]].approved;
    }

    function setApprovalForAll(address operator_, bool approved_) public virtual override {
        _setApprovalForAll(_msgSender(), operator_, approved_);
    }

    function isApprovedForAll(address owner_, address operator_) public view virtual override returns (bool) {
        return _addressData[owner_].approvals[operator_];
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index_) public view virtual override returns (uint256) {
        require(index_ < ERC3525Upgradeable.totalSupply(), "ERC3525: global index out of bounds");
        return _allTokens[index_].id;
    }

    function tokenOfOwnerByIndex(address owner_, uint256 index_) public view virtual override returns (uint256) {
        require(index_ < ERC3525Upgradeable.balanceOf(owner_), "ERC3525: owner index out of bounds");
        return _addressData[owner_].ownedTokens[index_];
    }

    /**
     * @notice Custom function to get the tokens of the owner
     * @param owner_ The owner of tokens
     */
    function _getOwnedTokens(address owner_) internal virtual returns (uint256[] memory) {
        return _addressData[owner_].ownedTokens;
    }

    function _setApprovalForAll(
        address owner_,
        address operator_,
        bool approved_
    ) internal virtual {
        require(owner_ != operator_, "ERC3525: approve to caller");

        _addressData[owner_].approvals[operator_] = approved_;

        emit ApprovalForAll(owner_, operator_, approved_);
    }

    function _isApprovedOrOwner(address operator_, uint256 tokenId_) internal view virtual returns (bool) {
        require(_exists(tokenId_), "ERC3525: operator query for nonexistent token");
        address owner = ERC3525Upgradeable.ownerOf(tokenId_);
        return (
            operator_ == owner ||
            ERC3525Upgradeable.isApprovedForAll(owner, operator_) ||
            getApproved(tokenId_) == operator_
        );
    }

    function _spendAllowance(address operator_, uint256 tokenId_, uint256 value_) internal virtual {
        uint256 currentAllowance = ERC3525Upgradeable.allowance(tokenId_, operator_);
        if (!_isApprovedOrOwner(operator_, tokenId_) && currentAllowance != type(uint256).max) {
            require(currentAllowance >= value_, "ERC3525: insufficient allowance");
            _approveValue(tokenId_, operator_, currentAllowance - value_);
        }
    }

    function _exists(uint256 tokenId_) internal view virtual returns (bool) {
        return _allTokens.length != 0 && _allTokens[_allTokensIndex[tokenId_]].id == tokenId_;
    }

    // event Merge(address indexed _owner, uint256 _tokenId, uint256 _value);
    /**
     * @notice Custom function to merge multiple tokens into one
     * @param tokenId_ The merged token
     * @param length_ The length of source tokens
     * @param tokenIds_ The selected token ids are about to merge
     */
    function _merge(uint256 tokenId_, uint256 length_, uint256[] memory tokenIds_) internal {
        TokenData storage targetTokenData = _allTokens[_allTokensIndex[tokenId_]];

        uint256 mintTime = targetTokenData.mintTime;
        uint256 balance = targetTokenData.balance;
        uint256 highYieldSecs = targetTokenData.highYieldSecs;
        uint256[] memory tokenIds = new uint256[](length_+1);
        uint256[] memory values = new uint256[](length_+1);
        tokenIds[0] = tokenId_;
        values[0] = targetTokenData.balance;

        for (uint256 i = 0; i < length_; i++) {
            TokenData memory sourceTokenData = _allTokens[_allTokensIndex[tokenIds_[i]]];
            balance += sourceTokenData.balance;
            _transferValue(
                sourceTokenData.id,
                targetTokenData.id,
                sourceTokenData.balance
            );

            highYieldSecs += _allTokens[_allTokensIndex[tokenIds_[i]]].highYieldSecs;

            if (mintTime < sourceTokenData.mintTime) {
                mintTime = sourceTokenData.mintTime;
            }

            _burn(tokenIds_[i]);
        }

        targetTokenData.mintTime = mintTime;
        targetTokenData.balance = balance;
        targetTokenData.highYieldSecs = highYieldSecs;

        emit Merge(_msgSender(), tokenId_, balance);
    }

    /**
     * @dev MUST emit when a token is splited to multiple tokens with the same slot
     * the total value of splited tokens must be the same as original value.
     * @param _owner The token owner
     * @param _tokenId The original token id
     * @param _tokenIds The splited token ids
     */
    event Split(address indexed _owner, uint256 _tokenId, uint256[] _tokenIds);

    /**
     * @notice Custom function to split one token to multiple tokens,
     * the total value of splited tokens must be the same as original value.
     * the origin token id should keep the value of index 0 of values_
     * @param tokenId_ The token id that owner wants to split
     * @param length_ The number of tokens after split
     * @param values_ The values distribution for splited token ids
     */
    function _split(uint256 tokenId_, uint256 length_, uint256[] memory values_) internal {
        uint256[] memory splitedTokens = new uint256[](length_);
        uint256 slot = ERC3525Upgradeable.slotOf(tokenId_);
        for (uint256 i = 0; i < length_; i++) {
            uint256 newTokenId = _createDerivedTokenId(tokenId_);
            _mint(_msgSender(), newTokenId, slot);
            _transferValue(tokenId_, newTokenId, values_[i]);
            splitedTokens[i] = newTokenId;
        }
        emit Split(_msgSender(), tokenId_, splitedTokens);
    }

    function _mintValue(address to_, uint256 slot_, uint256 value_) internal virtual returns (uint256) {
        uint256 tokenId = _createOriginalTokenId();

        require(to_ != address(0), "ERC3525: mint to the zero address");
        require(tokenId != 0, "ERC3525: cannot mint zero tokenId");
        require(!_exists(tokenId), "ERC3525: token already minted");

        _beforeValueTransfer(address(0), to_, 0, tokenId, slot_, value_);

        _mint(to_, tokenId, slot_);
        _allTokens[_allTokensIndex[tokenId]].balance = value_;

        emit TransferValue(0, tokenId, value_);

        _afterValueTransfer(address(0), to_, 0, tokenId, slot_, value_);

        return tokenId;
    }

    function _mint(address to_, uint256 tokenId_, uint256 slot_) private {
        
        TokenData memory tokenData = TokenData({
            id: tokenId_,
            slot: slot_,
            owner: to_,
            approved: address(0),
            valueApprovals: new address[](0),
            balance: 0,
            mintTime: block.timestamp,
            transferTime: block.timestamp,
            claimTime: block.timestamp,
            highYieldSecs: 0
        });

        _addTokenToAllTokensEnumeration(tokenData);
        _addTokenToOwnerEnumeration(to_, tokenId_);

        emit Transfer(address(0), to_, tokenId_);
        emit SlotChanged(tokenId_, 0, slot_);
    }

    function _burn(uint256 tokenId_) internal virtual {
        require(_exists(tokenId_), "ERC3525: token does not exist");

        TokenData memory tokenData = _allTokens[_allTokensIndex[tokenId_]];
        address owner = tokenData.owner;
        uint256 slot = tokenData.slot;
        uint256 value = tokenData.balance;

        _beforeValueTransfer(owner, address(0), tokenId_, 0, slot, value);

        _clearApprovedValues(tokenId_);
        _removeTimeInfoByTokenId(tokenId_);
        _removeTokenFromOwnerEnumeration(owner, tokenId_);
        _removeTokenFromAllTokensEnumeration(tokenId_);

        emit TransferValue(tokenId_, 0, value);
        emit Transfer(owner, address(0), tokenId_);
        emit SlotChanged(tokenId_, slot, 0);

        _afterValueTransfer(owner, address(0), tokenId_, 0, slot, value);
    }

    function _addTokenToOwnerEnumeration(address to_, uint256 tokenId_) private {
        _allTokens[_allTokensIndex[tokenId_]].owner = to_;

        _addressData[to_].ownedTokensIndex[tokenId_] = _addressData[to_].ownedTokens.length;
        _addressData[to_].ownedTokens.push(tokenId_);
    }

    function _removeTokenFromOwnerEnumeration(address from_, uint256 tokenId_) private {
        _allTokens[_allTokensIndex[tokenId_]].owner = address(0);

        AddressData storage ownerData = _addressData[from_];
        uint256 lastTokenIndex = ownerData.ownedTokens.length - 1;
        uint256 lastTokenId = ownerData.ownedTokens[lastTokenIndex];
        uint256 tokenIndex = ownerData.ownedTokensIndex[tokenId_];

        ownerData.ownedTokens[tokenIndex] = lastTokenId;
        ownerData.ownedTokensIndex[lastTokenId] = tokenIndex;

        delete ownerData.ownedTokensIndex[tokenId_];
        ownerData.ownedTokens.pop();
    }

    function _addTokenToAllTokensEnumeration(TokenData memory tokenData_) private {
        _allTokensIndex[tokenData_.id] = _allTokens.length;
        _allTokens.push(tokenData_);
    }

    function _removeTokenFromAllTokensEnumeration(uint256 tokenId_) private {
        // To prevent a gap in the tokens array, we store the last token in the index of the token to delete, and
        // then delete the last slot (swap and pop).

        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId_];

        // When the token to delete is the last token, the swap operation is unnecessary. However, since this occurs so
        // rarely (when the last minted token is burnt) that we still do the swap here to avoid the gas cost of adding
        // an 'if' statement (like in _removeTokenFromOwnerEnumeration)
        TokenData memory lastTokenData = _allTokens[lastTokenIndex];

        _allTokens[tokenIndex] = lastTokenData; // Move the last token to the slot of the to-delete token
        _allTokensIndex[lastTokenData.id] = tokenIndex; // Update the moved token's index

        // This also deletes the contents at the last position of the array
        delete _allTokensIndex[tokenId_];
        _allTokens.pop();
    }

    /**
     * @notice Custom function to update high yield seconds of token id
     * @param tokenId_ The token id needs to be updated
     * @param secs_ The high yield seconds will be claimed once redemption
     */
    function _updateHighYieldSecsByTokenId(uint256 tokenId_, uint256 secs_) internal returns (uint256) {
        _allTokens[_allTokensIndex[tokenId_]].highYieldSecs += secs_;
        return _allTokens[_allTokensIndex[tokenId_]].highYieldSecs;
    }

    /**
     * @notice Custom function to update transfer time of token id
     * @param tokenId_ The token id needs to be updated
     */
    function _updateTransferTimeByTokenId(uint256 tokenId_) internal {
        _allTokens[_allTokensIndex[tokenId_]].transferTime = block.timestamp;
    }

    /**
     * @notice Custom function to remove stake data of token id
     * @param tokenId_ The stake data of token id needs to be removed
     */
    function _removeTimeInfoByTokenId(uint256 tokenId_) internal {
        delete _allTokens[_allTokensIndex[tokenId_]].highYieldSecs;
        delete _allTokens[_allTokensIndex[tokenId_]].claimTime;
        delete _allTokens[_allTokensIndex[tokenId_]].transferTime;
        delete _allTokens[_allTokensIndex[tokenId_]].mintTime;
    }

    function _approve(address to_, uint256 tokenId_) internal virtual {
        _allTokens[_allTokensIndex[tokenId_]].approved = to_;
        emit Approval(ERC3525Upgradeable.ownerOf(tokenId_), to_, tokenId_);
    }

    function _approveValue(
        uint256 tokenId_,
        address to_,
        uint256 value_
    ) internal virtual {
        if (!_existApproveValue(to_, tokenId_)) {
            _allTokens[_allTokensIndex[tokenId_]].valueApprovals.push(to_);
        }
        _approvedValues[tokenId_][to_] = value_;

        emit ApprovalValue(tokenId_, to_, value_);
    }

    function _clearApprovedValues(uint256 tokenId_) internal virtual {
        TokenData storage tokenData = _allTokens[_allTokensIndex[tokenId_]];
        uint256 length = tokenData.valueApprovals.length;
        for (uint256 i = 0; i < length; i++) {
            address approval = tokenData.valueApprovals[i];
            delete _approvedValues[tokenId_][approval];
        }
    }

    function _existApproveValue(address to_, uint256 tokenId_) internal view virtual returns (bool) {
        uint256 length = _allTokens[_allTokensIndex[tokenId_]].valueApprovals.length;
        for (uint256 i = 0; i < length; i++) {
            if (_allTokens[_allTokensIndex[tokenId_]].valueApprovals[i] == to_) {
                return true;
            }
        }
        return false;
    }

    function _transferValue(
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 value_
    ) internal virtual {
        require(_exists(fromTokenId_), "ERC35255: transfer from nonexistent token");
        require(_exists(toTokenId_), "ERC35255: transfer to nonexistent token");

        TokenData storage fromTokenData = _allTokens[_allTokensIndex[fromTokenId_]];
        TokenData storage toTokenData = _allTokens[_allTokensIndex[toTokenId_]];

        require(fromTokenData.balance >= value_, "ERC3525: transfer amount exceeds balance");
        require(fromTokenData.slot == toTokenData.slot, "ERC3535: transfer to token with different slot");

        _beforeValueTransfer(
            fromTokenData.owner,
            toTokenData.owner,
            fromTokenId_,
            toTokenId_,
            fromTokenData.slot,
            value_
        );

        fromTokenData.balance -= value_;
        toTokenData.balance += value_;

        emit TransferValue(fromTokenId_, toTokenId_, value_);

        _afterValueTransfer(
            fromTokenData.owner,
            toTokenData.owner,
            fromTokenId_,
            toTokenId_,
            fromTokenData.slot,
            value_
        );

        require(
            _checkOnERC3525Received(fromTokenId_, toTokenId_, value_, ""),
            "ERC3525: transfer to non ERC3525Receiver"
        );
    }

    function _transferTokenId(
        address from_,
        address to_,
        uint256 tokenId_
    ) internal virtual {
        require(ERC3525Upgradeable.ownerOf(tokenId_) == from_, "ERC3525: transfer from incorrect owner");
        require(to_ != address(0), "ERC3525: transfer to the zero address");

        _beforeValueTransfer(from_, to_, tokenId_, tokenId_, slotOf(tokenId_), ERC3525Upgradeable.balanceOf(tokenId_));

        _approve(address(0), tokenId_);
        _clearApprovedValues(tokenId_);

        _removeTokenFromOwnerEnumeration(from_, tokenId_);
        _addTokenToOwnerEnumeration(to_, tokenId_);

        emit Transfer(from_, to_, tokenId_);

        _afterValueTransfer(from_, to_, tokenId_, tokenId_, slotOf(tokenId_), balanceOf(tokenId_));
    }

    function _safeTransferTokenId(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) internal virtual {
        _transferTokenId(from_, to_, tokenId_);
        require(
            _checkOnERC721Received(from_, to_, tokenId_, data_),
            "ERC3525: transfer to non ERC721Receiver"
        );
    }

    /**
     * @notice Custom function to set the claim time
     * @param tokenId_ the claimed token id
     * @param currtime_ the timestamp to set to claim time
     */
    function _setClaimTime(uint256 tokenId_, uint256 currtime_) internal {
        _allTokens[_allTokensIndex[tokenId_]].claimTime = currtime_;
    }

    function _checkOnERC3525Received( 
        uint256 fromTokenId_, 
        uint256 toTokenId_, 
        uint256 value_, 
        bytes memory data_
    ) private returns (bool) {
        address to = ownerOf(toTokenId_);
        if (to.isContract() && IERC165(to).supportsInterface(type(IERC3525Receiver).interfaceId)) {
            try
                IERC3525Receiver(to).onERC3525Received(_msgSender(), fromTokenId_, toTokenId_, value_, data_) returns (bytes4 retval) {
                return retval == IERC3525Receiver.onERC3525Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert( "ERC3525: transfer to non ERC3525Receiver");
                } else {
                    // solhint-disable-next-line
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /**
     * @dev Internal function to invoke {IERC721Receiver-onERC721Received} on a target address.
     * The call is not executed if the target address is not a contract.
     *
     * @param from_ address representing the previous owner of the given token ID
     * @param to_ target address that will receive the tokens
     * @param tokenId_ uint256 ID of the token to be transferred
     * @param data_ bytes optional data to send along with the call
     * @return bool whether the call correctly returned the expected magic value
     */
    function _checkOnERC721Received(
        address from_,
        address to_,
        uint256 tokenId_,
        bytes memory data_
    ) private returns (bool) {
        if (to_.isContract() && IERC165(to_).supportsInterface(type(IERC721Receiver).interfaceId)) {
            try 
                IERC721Receiver(to_).onERC721Received(_msgSender(), from_, tokenId_, data_) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver");
                } else {
                    // solhint-disable-next-line
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }

    /* solhint-disable */
    function _beforeValueTransfer(
        address from_,
        address to_,
        uint256 fromTokenId_,
        uint256 toTokenId_,
        uint256 slot_,
        uint256 value_
    ) internal virtual {
        if (_derivedTokenId[toTokenId_]) {
            // splited token should be inherited all time info from the original token
            TokenData memory sourceTokenData = _allTokens[_allTokensIndex[fromTokenId_]];
            TokenData storage targeTokenData = _allTokens[_allTokensIndex[toTokenId_]];
            targeTokenData.mintTime = sourceTokenData.mintTime;
            targeTokenData.transferTime = sourceTokenData.transferTime;
            targeTokenData.claimTime = sourceTokenData.claimTime;
            targeTokenData.highYieldSecs = sourceTokenData.highYieldSecs;
        }

        from_;
        to_;
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
    ) internal virtual {}

    /* solhint-enable */

    function _setMetadataDescriptor(address metadataDescriptor_) internal virtual {
        metadataDescriptor = IERC3525MetadataDescriptor(metadataDescriptor_);
        emit SetMetadataDescriptor(metadataDescriptor_);
    }

    function _createOriginalTokenId() internal virtual returns (uint256) {
        return _createDefaultTokenId();
    }

    function _createDerivedTokenId(uint256 fromTokenId_) internal virtual returns (uint256) {
        _derivedTokenId[fromTokenId_] = true;
        return _createDefaultTokenId();
    }

    function _createDefaultTokenId() private view returns (uint256) {
        return totalSupply() + 1;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     */
    uint256[42] private __gap;
}
