// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

library Constants {
    enum ClaimType {
        LINEAR,
        ONE_TIME,
        STAGED
    }

    enum VoucherType {
        STANDARD_VESTING,
        FLEXIBLE_DATE_VESTING,
        BOUNDING
    }

    struct NftBalance {
        uint256 stakingAmount;
        uint256 burnableAmount;
    }

    struct StakingInfo {
        uint256 stakeNFTamount;
        uint256 leftToUnstakeNFTamount;
        uint256 staketime;
        uint256 unstaketime;
        bool isUnstake;
    }

    uint32 internal constant FULL_PERCENTAGE = 10000;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant RE_NFT =
        0x502818ec5767570F7fdEe5a568443dc792c4496b;
    address internal constant RE_STAKE =
        0x10a92B12Da3DEE9a3916Dbaa8F0e141a75F07126;
    address internal constant FREE_MINT =
        0x10a92B12Da3DEE9a3916Dbaa8F0e141a75F07126;
    address internal constant MULTISIG =
        0xAcB683ba69202c5ae6a3B9b9b191075295b1c41C;
    address internal constant REGENERATIVE_NFT = address(0);

    error NotQualified();
    error InvalidSlot();
    error ExceedTVL();
    error NotOwner();
    error OnlyStake();
    error NotApproved();
    error NotClamiable();
    error InsufficientBalance();
    error ExceedUnits();
}
