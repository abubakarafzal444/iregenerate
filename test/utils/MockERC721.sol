// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solmate/tokens/ERC721.sol";

contract MockERC721 is ERC721 {

    uint256 private _tokenId;

    constructor() ERC721("", "") {}

    function tokenURI(uint256 id) public view virtual override returns (string memory) {
        id;
        return "";
    }

    function mint() external {
        uint256 currToken = _tokenId;
        _mint(msg.sender, currToken+1);
    }
}