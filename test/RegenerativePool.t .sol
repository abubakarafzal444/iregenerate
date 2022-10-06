// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Constants.sol";
import { RegenerativePool } from "../src/RegenerativePool.sol";
import { RegenerativeNFT } from "../src/RegenerativeNFT.sol";

contract RegenerativeTest is Test {
    using stdStorage for StdStorage;

    TestUSDC erc20;
    RegenerativeNFT nft;
    RegenerativePool pool;

    uint256 constant ONE_UNIT = 10**6;

    address owner = makeAddr("owner");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address charlie = makeAddr("charlie");

    function setUp() public {
        vm.startPrank(owner);

        erc20 = new TestUSDC("TestUSDC", "TUSDC");

        nft = new RegenerativeNFT();
        nft.initialize("RegenerativeNFT", "RGT", 6);
        nft.createSlot(
            1,
            2_000_000 * ONE_UNIT,
            300 * ONE_UNIT,
            address(erc20),
            Constants.MATURITY
        );

        uint256[] memory slots = new uint256[](1);
        slots[0] = 1;
        pool = new RegenerativePool();
        pool.initialize(address(nft), Constants.LOCK_TIME, address(erc20), slots);
        nft.setRegenerativePool(address(pool));

        deal(address(erc20), alice, 1_000_000 * ONE_UNIT);
        deal(address(erc20), bob, 1_000_000 * ONE_UNIT);
        deal(address(erc20), charlie, 1_000_000 * ONE_UNIT);
        deal(address(erc20), address(pool), 1_000_000 * ONE_UNIT);

        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);

        changePrank(bob);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);
        vm.stopPrank();
    }
    // =========== Regenerative NFT UNIT TEST Start ===========
     function testBurn() public {
        vm.prank(address(pool));
        nft.burn(1);
        vm.expectRevert("ERC3525: owner query for nonexistent token");
        nft.ownerOf(1);
    }

    function testCannotBurnWithOnlyPool() public {
        vm.expectRevert(Constants.OnlyPool.selector);
        nft.burn(1);
    }

    function testUpdateStakeDataByTokenId() public {
        uint256 beforeUpdate = nft.highYieldSecsOf(1);
        vm.prank(address(pool));
        nft.updateStakeDataByTokenId(1, 20);
        uint256 afterUpdate = nft.highYieldSecsOf(1);
        assertEq(afterUpdate - beforeUpdate, 20);
    }

    function testRemoveStakeDataByTokenId() public {
        stdstore
            .target(address(nft))
            .sig(nft.highYieldSecsOf.selector)
            .with_key(1)
            .checked_write(20);
        uint256 beforeRemove = nft.highYieldSecsOf(1);
        vm.prank(address(pool));
        nft.removeStakeDataByTokenId(1);
        uint256 afterRemove = nft.highYieldSecsOf(1);
        assertEq(beforeRemove - afterRemove, 20);
    }
    // =========== Regenerative NFT UNIT TEST End ===========

    // =========== Regenerative Pool UNIT TEST Start ===========
    function testStakeWithOneToken() public {
        uint256 beforeStake = pool.balanceOf(bob);
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        pool.stake(1, nft.balanceOf(1));
        vm.stopPrank();
        uint256 afterStake = pool.balanceOf(bob);
        assertEq(afterStake - beforeStake, 1);
    }

    function testStakeWithOneTokenOfPartialValue() public {
        uint256 beforeStake = nft.balanceOf(1);
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        pool.stake(1, 500 * ONE_UNIT);
        vm.stopPrank();
        uint256 afterStake = nft.balanceOf(1);
        assertEq(beforeStake - afterStake, 500 * ONE_UNIT);
    }

    function testStakeWithTokensOfPartialValues() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        values[0] = nft.balanceOf(1);
        values[1] = 5_000 * ONE_UNIT;

        uint256 beforeStake = pool.balanceOf(bob);
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        pool.stake(tokenIds, values);
        vm.stopPrank();
        uint256 afterStake = pool.balanceOf(bob);
        assertEq(afterStake - beforeStake, 2);
    }

    function testCannotStakeWithListMismatch() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory values = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        values[0] = nft.balanceOf(1);
        values[1] = 5_000 * ONE_UNIT;
        values[2] = 0;

        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        vm.expectRevert(Constants.ListMismatch.selector);
        pool.stake(tokenIds, values);
        vm.stopPrank();
    }

    function testCannotStakeWithNotOwner() public {
        vm.startPrank(alice);
        nft.setApprovalForAll(address(pool), true);
        vm.expectRevert(Constants.NotOwner.selector);
        pool.stake(1, nft.balanceOf(1));
        vm.stopPrank();
    }

    function testCannotStakeWithExceedBalance() public {
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        uint256 value = nft.balanceOf(1) + 1;
        vm.expectRevert("ERC3525: transfer amount exceeds balance");
        pool.stake(1, value);
        vm.stopPrank();
    }

    function testCannotStakeWithInvalidValue() public {
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        vm.expectRevert(Constants.InvalidValue.selector);
        pool.stake(1, 0);
        vm.stopPrank();
    }

    function testClaim() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        values[0] = nft.balanceOf(1);
        values[1] = 5_000 * ONE_UNIT;

        uint256 beforeClaim = erc20.balanceOf(bob);
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        pool.stake(tokenIds, values);
        skip(Constants.LOCK_TIME);
        pool.claim();
        vm.stopPrank();
        uint256 afterClaim = erc20.balanceOf(bob);
        assertTrue(afterClaim - beforeClaim > 0);
    }

    function testCannotClaimWithNotClaimable() public {
        uint256[] memory tokenIds = new uint256[](2);
        uint256[] memory values = new uint256[](2);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        values[0] = nft.balanceOf(1);
        values[1] = 5_000 * ONE_UNIT;

        uint256 beforeClaim = erc20.balanceOf(bob);
        vm.startPrank(bob);
        nft.setApprovalForAll(address(pool), true);
        pool.stake(tokenIds, values);
        skip(2);
        vm.expectRevert(Constants.NotClaimable.selector);
        pool.claim();
        vm.stopPrank();
        uint256 afterClaim = erc20.balanceOf(bob);
        assertTrue(afterClaim - beforeClaim > 0);
    }
    // =========== Regenerative Pool UNIT TEST End ===========
}