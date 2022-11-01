// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC3525/IERC3525.sol";

library RegenerativeUtils {
    error BelowMinimumValue();
    error ExceedBalance();
    error ExceedUnits();
    error InsufficientBalance();
    error InvalidSlot();
    error InvalidToken();
    error InvalidValue();
    error ListMismatch();
    error MismatchValue(uint256 _expected, uint256 _actual);
    error NotClaimable();
    error NotIssuer();
    error NotOwner();
    error NotQualified();
    error NotRedeemable();
    error NotStaker();
    error OnlyPool();

    enum YieldType {
        BONUS_YIELD,
        BASE_YIELD
    }

    uint256 internal constant BASE_APR = 15;
    uint256 internal constant HIGH_APR = 25;
    uint32 internal constant PERCENTAGE = 100;
    uint256 internal constant YEAR_IN_SECS = 31_536_000;
    uint256 internal constant MATURITY = 46_656_000;
    uint256 internal constant LOCK_TIME = 8_640_000;

    // Production
    address internal constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address internal constant RE_NFT = 0x502818ec5767570F7fdEe5a568443dc792c4496b;
    // address internal constant RE_STAKE = 0x10a92B12Da3DEE9a3916Dbaa8F0e141a75F07126;

    // Test
    address internal constant RE_NFT = 0x72cC13426cAfD2375FFABE56498437927805d3d2;
    address internal constant RE_STAKE = 0x98B3c60ADE6A87b229Aa7d91ad27c227d54d95C0;
    address internal constant ASSET_NFT = 0x98B3c60ADE6A87b229Aa7d91ad27c227d54d95C0;

    address internal constant FREE_MINT = 0xCeF98e10D1e80378A9A74Ce074132B66CDD5e88d;
    address internal constant MULTISIG = 0xAcB683ba69202c5ae6a3B9b9b191075295b1c41C;

    function _calculateClaimableInterest(
        uint256 value_,
        uint256 secs_,
        YieldType yieldType_
    ) internal pure returns (uint256) {
        uint256 apr = 0;
        if (yieldType_ == YieldType.BONUS_YIELD) {
            apr = HIGH_APR - BASE_APR;
        } else if (yieldType_ == YieldType.BASE_YIELD) {
            apr = BASE_APR;
        }
        return
            (secs_ * apr * value_) /
            (YEAR_IN_SECS * PERCENTAGE);
    }
}
