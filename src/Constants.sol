// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";

library Constants {
    enum YieldType {
        BONUS_APR,
        BASE_APR
    }

    uint256 internal constant BASE_APR = 15;
    uint256 internal constant HIGH_APR = 25;
    uint32 internal constant PERCENTAGE = 100;
    uint256 internal constant YEAR_IN_SECS = 31_536_000;
    uint256 internal constant MATURITY = 46_656_000;
    uint256 internal constant LOCK_TIME = 8_640_000;
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address internal constant RE_NFT = 0x502818ec5767570F7fdEe5a568443dc792c4496b;
    address internal constant RE_STAKE = 0x10a92B12Da3DEE9a3916Dbaa8F0e141a75F07126;
    address internal constant FREE_MINT = 0x10a92B12Da3DEE9a3916Dbaa8F0e141a75F07126;
    address internal constant MULTISIG = 0xAcB683ba69202c5ae6a3B9b9b191075295b1c41C;

    error BelowMinimumValue();
    error ExceedBalance();
    error ExceedUnits();
    error InsufficientBalance();
    error InvalidSlot();
    error InvalidValue();
    error ListMismatch();
    error MismatchValue(uint256 _expected, uint256 _actual);
    error NotClaimable();
    error NotOwner();
    error NotQualified();
    error NotRedeemable();
    error NotStaker();
    error OnlyPool();
}
