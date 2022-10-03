//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525/ERC3525SlotEnumerableUpgradeable.sol";

interface IRegenerative {
    function balanceInSlot(uint256 slot_) external view returns (uint256);

    function slotTotalValue(uint256 slot_) external view returns (uint256);

    function addValueInSlot(uint256 slot_, uint256 rwaAmount_) external;

    function removeValueInSlot(uint256 slot_, uint256 rwaAmount_) external;

    function createSlot(uint256 rwaAmount_, uint256 rwaValue_, uint256 minimumValue_, address currency_) external;

    function highYieldSecsOf(uint256 tokenId_) external view returns (uint256);

    function mint(uint256 slot_, uint256 value_) external;

    function merge(uint256[] calldata tokenIds_) external;

    function burn(uint256 tokenId_) external;

    function updateStakeDataByTokenId(uint256 tokenId_, uint256 secs_) external;

    function removeStakeDataByTokenId(uint256 tokenId_) external;
}

interface OwnerChecker {
    function balanceOf(address account) external view returns (uint256);

    function nftBalance(address account)
        external
        view
        returns (Constants.NftBalance memory);
}
