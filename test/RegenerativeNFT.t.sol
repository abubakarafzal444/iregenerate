// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/RegenerativeUtils.sol";
import { RegenerativeNFT, ERC3525Upgradeable } from "../src/RegenerativeNFT.sol";
import { MockERC20 } from "./utils/MockERC20.sol";
import { MockERC721 } from "./utils/MockERC721.sol";
import { MockERC1155 } from "./utils/MockERC1155.sol";
import { MockStake } from "./utils/MockStake.sol";

contract RegenerativeNFTTest is Test {
    using stdStorage for StdStorage;

    MockERC20 internal erc20;
    MockERC721 internal erc721;
    MockERC721 internal asset;
    MockERC1155 internal erc1155;
    MockStake internal stake;
    RegenerativeNFT internal nft;

    uint256 constant ONE_UNIT = 10**6;

    address owner = makeAddr("owner");
    address originator = makeAddr("originator");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    function initERC20() public {
        vm.startPrank(owner);
        erc20 = new MockERC20();
        deal(address(erc20), alice, 1_000_000 * ONE_UNIT);
        vm.stopPrank();
    }

    function initAsset() private {
        vm.startPrank(owner);
        asset = new MockERC721();
        changePrank(originator);
        asset.mintAsset(2_000_000 * ONE_UNIT, uint64(RegenerativeUtils.MATURITY));
        vm.stopPrank();
        emit log_named_address("MockAsset", address(asset));
    }

    function initERC721() private {
        vm.startPrank(owner);
        erc721 = new MockERC721();
        changePrank(alice);
        asset.mint();
        vm.stopPrank();
        emit log_named_address("MockERC721", address(erc721));
    }
    
    function initERC1155() private {
        vm.startPrank(owner);
        erc1155 = new MockERC1155();
        changePrank(alice);
        erc1155.mint(1, 10);
        vm.stopPrank();
        emit log_named_address("MockERC1155", address(erc1155));
    }

    function initStake() private {
        vm.startPrank(owner);
        stake = new MockStake(address(erc1155));
        changePrank(alice);
        erc1155.setApprovalForAll(address(stake), true);
        stake.stake(2);
        vm.stopPrank();
        emit log_named_address("MockStake", address(stake));
    }

    function initERC3525() private {
        vm.startPrank(owner);
        nft = new RegenerativeNFT();
        nft.initialize("RegenerativeNFT", "RGT", 6, address(erc20));
        deal(address(erc20), address(nft), 2_000_000 * ONE_UNIT);
        vm.stopPrank();
    }

    function setUp() public {
        initERC20();
        initAsset();
        initERC721();
        initERC1155();
        initStake();
        initERC3525();
    }

    function testCreateSlot() public {
        uint256 beforeCreate = nft.slotCount();
        vm.prank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        uint256 afterCreate = nft.slotCount();
        assertEq(afterCreate - beforeCreate, 1);
    }

    function testMint() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        vm.stopPrank();
        assertEq(alice, nft.ownerOf(1));
        assertEq(1_000 * ONE_UNIT, nft.balanceOf(1));
    }

    function testCannotMintWithInvalidSlot() public {
        vm.prank(alice);
        vm.expectRevert(RegenerativeUtils.InvalidSlot.selector);
        nft.mint(1, 300 * ONE_UNIT);
    }

    function testCannotMintWithInsufficientBalance() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        vm.expectRevert(RegenerativeUtils.InsufficientBalance.selector);
        nft.mint(1, 200_000_000 * ONE_UNIT);
        vm.stopPrank();
    }

    function testCannotMintWithBelowMinimumValue() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        vm.expectRevert(RegenerativeUtils.BelowMinimumValue.selector);
        nft.mint(1, 200 * ONE_UNIT);
        vm.stopPrank();
    }

    function testMerge() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);

        ERC3525Upgradeable.TokenData memory beforeMerge = nft.getTokenSnapshot(1);
        nft.merge(1, tokenIds);
        ERC3525Upgradeable.TokenData memory afterMerge = nft.getTokenSnapshot(1);
        vm.stopPrank();
        assertEq(afterMerge.balance - beforeMerge.balance, 29_000 * ONE_UNIT);
    }

    function testCannotMergeWithNotOwner() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 2;
        tokenIds[1] = 3;

        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);

        changePrank(bob);
        vm.expectRevert(RegenerativeUtils.NotOwner.selector);
        nft.merge(1, tokenIds);
        vm.stopPrank();
    }

    function testSplit() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 300 * ONE_UNIT;
        values[1] = 400 * ONE_UNIT;

        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);

        uint256 beforeSplit = nft.balanceOf(alice);
        nft.split(1, 300 * ONE_UNIT, values);
        uint256 afterSplit = nft.balanceOf(alice);
        vm.stopPrank();
        assertEq(afterSplit - beforeSplit, 2);
    }

    function testCannotSplitWithNotOwner() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 300 * ONE_UNIT;
        values[1] = 400 * ONE_UNIT;

        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);

        changePrank(bob);
        vm.expectRevert(RegenerativeUtils.NotOwner.selector);
        nft.split(1, 300 * ONE_UNIT, values);
        vm.stopPrank();
    }

    function testCannotSplitWithMismatchValue() public {
        uint256[] memory values = new uint256[](2);
        values[0] = 300 * ONE_UNIT;
        values[1] = 300 * ONE_UNIT;

        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);

        vm.expectRevert(
            abi.encodeWithSelector(
                RegenerativeUtils.MismatchValue.selector,
                1000 * ONE_UNIT,
                900 * ONE_UNIT
            )
        );
        nft.split(1, 300 * ONE_UNIT, values);
        vm.stopPrank();
    }

    function testAddValueToSlot() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        uint256 addedValue = nft.balanceOfSlot(1);
        vm.stopPrank();
        assertEq(addedValue, 2_000_000 * ONE_UNIT);
    }

    function testRemoveValueInSlot() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        nft.removeValueFromSlot(1, 1);
        uint256 afterRemoveValue = nft.balanceOfSlot(1);
        vm.stopPrank();
        assertEq(afterRemoveValue, 0);
    }

    function testClaim() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);
        skip(RegenerativeUtils.LOCK_TIME);
        uint256 beforeClaim = nft.getTokenSnapshot(1).claimTime;
        nft.claim();
        vm.stopPrank();
        uint256 afterClaim = nft.getTokenSnapshot(1).claimTime;
        assertEq(RegenerativeUtils.LOCK_TIME, afterClaim - beforeClaim);
    }

    function testCannotClaimWithNotClaimable() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        vm.expectRevert(abi.encodeWithSelector(RegenerativeUtils.NotClaimable.selector));
        nft.claim();
        vm.stopPrank();
    }

    function testRedeem() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        
        skip(2_000);
        stake.stake(1);
        skip(1_500);
        stake.stake(2);
        skip(500);
        stake.unStake(3);
        skip(RegenerativeUtils.MATURITY);
        emit log_named_uint("Current Time", block.timestamp);
        nft.redeem(1);
        vm.stopPrank();
    }

    function testRedeemWithMultipleTokens() public {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        skip(2_000);
        stake.stake(1);
        skip(1_500);
        nft.mint(1, 2_000 * ONE_UNIT);
        stake.stake(2);
        skip(500);
        stake.unStake(3);
        skip(RegenerativeUtils.MATURITY);
        nft.redeem(tokenIds);
        vm.stopPrank();
    }

    function testRedeemWithTransferId() public {
        vm.startPrank(owner);
        nft.createSlot(
            originator,
            2_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            RegenerativeUtils.MATURITY
        );
        changePrank(originator);
        asset.setApprovalForAll(address(nft), true);
        nft.addValueToSlot(1, 1, 1);
        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        skip(2_000);
        stake.stake(1);
        skip(1_000);
        stake.stake(2);
        skip(500);
        stake.unStake(5);
        skip(RegenerativeUtils.LOCK_TIME - 3500);
        nft.claim();
        skip(500);
        nft.safeTransferFrom(alice, bob, 1);
        skip(RegenerativeUtils.MATURITY - RegenerativeUtils.LOCK_TIME);
        changePrank(bob);
        nft.redeem(1);
        vm.stopPrank();
    }
}