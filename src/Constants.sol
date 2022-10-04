// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "./ERC3525/IERC3525.sol";
import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "./IRegenerative.sol";

library Constants {
    enum YieldType {
        BONUS_APR,
        BASE_APR
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

    uint256 internal constant BASE_APR = 15;
    uint256 internal constant HIGH_APR = 25;
    uint32 internal constant PERCENTAGE = 100;
    uint256 internal constant YEAR_IN_SECS = 31_536_000;
    uint256 internal constant MATURITY = 46_656_000;
    uint256 internal constant LOCK_TIME = 1235468;
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

    error NotQualified();
    error InvalidSlot();
    error ExceedTVL();
    error NotOwner();
    error NotStaker();
    error OnlyPool();
    error NotApproved();
    error NotClamiable();
    error NotRedeemable();
    error InsufficientBalance();
    error ExceedUnits();
    error ListMismatch();
    error MismatchValue();

    function transferCurrencyTo(
        address to_,
        address currency_,
        uint256 value_,
        uint256 valueDecimals_
    ) internal returns(bool) {
        
        uint256 balance = value_ * 10**ERC20(currency_).decimals() /
        10**valueDecimals_;
        
        return IERC20(currency_).transferFrom(msg.sender, to_, balance);
    }
}
