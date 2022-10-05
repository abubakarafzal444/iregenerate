//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Regenerative NFT
 */
interface IRegenerative {
    /**
     * @dev MUST emit when a token is splited to multiple tokens with the same slot
     * the total value of splited tokens must be the same as original value.
     * @param _owner The token owner
     * @param _tokenId The splited token id
     * @param _units The token id is splited to
     * @param _value The total value of splited tokens
     */
    event Split(address indexed _owner, uint256 indexed _tokenId, uint256 _units, uint256 _value);
    
    /**
     * @dev MUST emit when multiple tokens with the same slot is merged into one token
     * @param _owner The tokens owner
     * @param _units The number of tokens are merged
     * @param _value The total value of merged token
     */
    event Merge(address indexed _owner, uint256 _units, uint256 _value);

    /**
     * @dev MUST emits when the total value of slot is changed
     * @param _slot The slot whose value is set or changed
     * @param _oldValue The previous value of the slot
     * @param _newValue The updated value of the slot
     */
    event SlotValueChanged(uint256 indexed _slot, uint256 _oldValue, uint256 _newValue);

    /**
     * @notice Get the maturity of the token
     * @param _tokenId The token id
     * @return The maturity of the `_tokenId`
     */
    function maturityOf(uint256 _tokenId) external view returns (uint256);

    /**
     * @notice Get the balance of the slot
     * @param _slot The slot id
     * @return The balance of the `_slot`
     */
    function balanceInSlot(uint256 _slot) external view returns (uint256);

    /**
     * @notice Get the Total value of the slot
     * @param _slot The slot id
     * @return The total value of the `_slot`
     */
    function slotTotalValue(uint256 _slot) external view returns (uint256);

    /**
     * @notice Add the value into the slot by RWA amount
     * @param _slot The slot whose value is about to add
     * @param _rwaAmount The RWA amount is about to add into the slot
     */
    function addValueInSlot(uint256 _slot, uint256 _rwaAmount) external;

    /**
     * @notice Remove the value into the slot by RWA amount
     * @param _slot The slot whose value is about to remove
     * @param _rwaAmount The RWA amount is about to remove from the slot
     */
    function removeValueInSlot(uint256 _slot, uint256 _rwaAmount) external;

    /**
     * @notice create a new slot to a corresponding RWA
     * @param _rwaAmount The RWA amount this slot would store
     * @param _rwaValue The value of one RWA
     * @param _minimumValue The minimum value for minting
     * @param _currency The currency for minting the token with this slot
     * @param _maturity The maturity of the token
     */
    function createSlot(uint256 _rwaAmount, uint256 _rwaValue, uint256 _minimumValue, address _currency, uint256 _maturity) external;

    /**
     * @notice Get the high yield seconds of the token
     * @param _tokenId The token id
     * @return The high yield seconds of the `_tokenId`
     */
    function highYieldSecsOf(uint256 _tokenId) external view returns (uint256);

    /**
     * @notice Mint a token with the slot for the specific value
     * @param _slot The slot of a RWA
     */
    function mint(uint256 _slot, uint256 _value) external;

    /**
     * @notice Merge multiple tokens with the same slot into one token
     * @param _tokenIds The merged tokens
     */
    function merge(uint256[] memory _tokenIds) external;

    /**
     * @notice Split one token into multiple tokens
     * @dev MUST check the splited values should be the same of the original value
     * @param _tokenId The splited token
     * @param _values The list of values for each splited token
     */
    function split(uint256 _tokenId, uint256[] memory _values) external;

    /**
     * @notice Burn the token
     * @param _tokenId The token id
     */
    function burn(uint256 _tokenId) external;

    /**
     * @notice Update the stake data of the token, this function is to interact
     * with the regenerative pool
     * @param _tokenId The token id whose data is about to be updated
     * @param _secs The high yield seconds
     */
    function updateStakeDataByTokenId(uint256 _tokenId, uint256 _secs) external;

    /**
     * @notice Remove the stake data of the token, this function is to interact
     * with the regenerative pool
     * @param _tokenId The token id whose data is about to be removed 
     */
    function removeStakeDataByTokenId(uint256 _tokenId) external;
}