// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";
import "openzeppelin-contracts/utils/Counters.sol";

contract MockERC721 is ERC721 {
    using Counters for Counters.Counter;

    struct TokenData {
        address originator;
        uint256 assetValue;
        uint64 maturity;
    }

    Counters.Counter private _currentTokenId;
    mapping(uint256 => TokenData) public data;

    constructor() ERC721("", "") {}

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        id;
        return "";
    }

    function mintAsset(uint256 _assetValue, uint64 _maturity) external {
        _currentTokenId.increment();
        uint256 tokenId = _currentTokenId.current();
        data[tokenId] = TokenData({
            originator: msg.sender,
            assetValue: _assetValue,
            maturity: _maturity
        });
        _mint(msg.sender, tokenId);
    }

    function mint() external {
        _currentTokenId.increment();
        uint256 tokenId = _currentTokenId.current();
        _mint(msg.sender, tokenId);
    }
}