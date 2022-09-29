//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRegenerative {
    function balanceInSlot(uint256 slot_) external view returns (uint256);

    function slotTotalValue(uint256 slot_) external view returns (uint256);

    function addValueInSlot(uint256 slot_, uint256 rwaAmount_) external;

    function removeValueInSlot(uint256 slot_, uint256 rwaAmount_) external;

    function createSlot(uint256 rwaAmount_, uint256 rwaValue_) external;

    function highYieldSecsOf(uint256 tokenId_) external view returns (uint256);

    function mint(address currency_, uint256 slot_, uint256 value_) external;

    function merge(uint256[] calldata tokenIds_) external;

    function burn(uint256 tokenId_) external;

    function updateStakeDataByTokenId(uint256 tokenId_, uint256 secs_) external;

    function removeStakeDataByTokenId(uint256 tokenId_) external;
}

struct NftBalance {
    uint256 stakingAmount;
    uint256 burnableAmount;
}

interface OwnerChecker {
    function balanceOf(address account) external view returns (uint256);

    function nftBalance(address account)
        external
        view
        returns (NftBalance memory);
}