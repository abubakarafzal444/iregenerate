//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Regenerative NFT
 */
interface IRegenerative {
    enum Operation {
        Claim,
        Merge,
        Split
    }

    struct Duration {
        uint64 start;
        uint64 end;
    }

    event Claim(address indexed _to, Operation indexed _operation, uint256[] _tokenIds, uint256[] _values, uint256[] _balances);
    event Redeem(address indexed _to, uint256 _principal, uint256 _interest);
    event UpdateDuration(address indexed _staker, uint256 _index, uint256 _start, uint256 _end);

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
    function balanceOfSlot(uint256 _slot) external view returns (uint256);

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
     * @param _tokenId The RWA token id
     */
    function addValueToSlot(uint256 _slot, uint256 _rwaAmount, uint256 _tokenId) external;

    /**
     * @notice Remove the value into the slot by RWA amount
     * @param _slot The slot whose value is about to remove
     * @param _rwaAmount The RWA amount is about to remove from the slot
     */
    function removeValueFromSlot(uint256 _slot, uint256 _rwaAmount) external;

    /**
     * @notice create a new slot to a corresponding RWA
     * @param _issuer The RWA owner
     * @param _rwaValue The value of one RWA
     * @param _minimumValue The minimum value for minting
     * @param _maturity The maturity of the token
     */
    function createSlot(address _issuer, uint256 _rwaValue, uint256 _minimumValue, uint256 _maturity) external;

    /**
     * @notice Mint a token with the slot for the specific value
     * @param _slot The slot of a RWA
     */
    function mint(uint256 _slot, uint256 _value) external;

    /**
     * @notice Merge multiple tokens with the same slot into one token
     * @param _tokenId The merged token
     * @param _tokenIds The source tokens are about to be merged
     */
    function merge(uint256 _tokenId, uint256[] memory _tokenIds) external;

    /**
     * @notice Split one token into multiple tokens
     * @dev MUST check the splited values should be the same of the original value
     * @param _tokenId The splited token
     * @param _value The value that origial token remains
     * @param _values The list of values for each splited token
     */
    function split(uint256 _tokenId, uint256 _value, uint256[] memory _values) external;
}