// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/RegenerativeNFT.sol";

contract RegenerativeTest is Test {
    using stdStorage for StdStorage;

    TestUSDC erc20;
    RegenerativeNFT nft;

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

        deal(address(erc20), alice, 1_000_000 * ONE_UNIT);
        deal(address(erc20), bob, 1_000_000 * ONE_UNIT);
        deal(address(erc20), charlie, 1_000_000 * ONE_UNIT);

        changePrank(alice);
        erc20.approve(address(nft), UINT256_MAX);

        changePrank(bob);
        erc20.approve(address(nft), UINT256_MAX);
        nft.mint(1, 1_000 * ONE_UNIT);
        nft.mint(1, 20_000 * ONE_UNIT);
        nft.mint(1, 9_000 * ONE_UNIT);
        vm.stopPrank();
    }

    function testCreateSlot() public {
        uint256 beforeCreate = nft.slotCount();
        vm.prank(owner);
        nft.createSlot(
            1,
            1_000_000 * ONE_UNIT,
            1_000 * ONE_UNIT,
            address(erc20),
            Constants.MATURITY
        );
        uint256 afterCreate = nft.slotCount();
        assertEq(afterCreate - beforeCreate, 1);
    }

    function testMint() public {
        vm.prank(alice);
        nft.mint(1, 1_000 * 10**erc20.decimals());
        assertEq(alice, nft.ownerOf(4));
    }

    function testCannotMintWithInvalidSlot() public {
        vm.prank(alice);
        vm.expectRevert(Constants.InvalidSlot.selector);
        nft.mint(2, 300 * ONE_UNIT);
    }

    function testCannotMintWithInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(Constants.InsufficientBalance.selector);
        nft.mint(1, 200_000_000 * ONE_UNIT);
    }

    function testCannotMintWithBelowMinimumValue() public {
        vm.prank(alice);
        vm.expectRevert(Constants.BelowMinimumValue.selector);
        nft.mint(1, 200 * ONE_UNIT);
    }

    function testMerge() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        ERC3525Upgradeable.TokenData memory beforeMerge = nft.getTokenSnapshot(1);
        vm.prank(bob);
        nft.merge(tokenIds);
        ERC3525Upgradeable.TokenData memory afterMerge = nft.getTokenSnapshot(1);
        assertEq(afterMerge.balance - beforeMerge.balance, 29_000 * ONE_UNIT);
    }

    function testCannotMergeWithNotOwner() public {
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 3;
        vm.prank(alice);
        vm.expectRevert(Constants.NotOwner.selector);
        nft.merge(tokenIds);
    }

    function testSplit() public {
        uint256 beforeSplit = nft.balanceOf(bob);
        uint256[] memory values = new uint256[](3);
        values[0] = 300 * ONE_UNIT;
        values[1] = 300 * ONE_UNIT;
        values[2] = 400 * ONE_UNIT;
        vm.prank(bob);
        nft.split(1, values);
        uint256 afterSplit = nft.balanceOf(bob);
        assertEq(afterSplit - beforeSplit, 2);
    }

    function testCannotSplitWithNotOwner() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 300 * ONE_UNIT;
        values[1] = 300 * ONE_UNIT;
        values[2] = 400 * ONE_UNIT;
        vm.prank(alice);
        vm.expectRevert(Constants.NotOwner.selector);
        nft.split(1, values);
    }

    function testCannotSplitWithMismatchValue() public {
        uint256[] memory values = new uint256[](3);
        values[0] = 300 * ONE_UNIT;
        values[1] = 300 * ONE_UNIT;
        values[2] = 300 * ONE_UNIT;
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Constants.MismatchValue.selector,
                1000 * ONE_UNIT,
                900 * ONE_UNIT
            )
        );
        nft.split(1, values);
    }

    function testAddValueInSlot() public {
        vm.startPrank(owner);
        uint256 beforeAddValue = nft.balanceInSlot(1);
        nft.addValueInSlot(1, 1);
        uint256 afterAddValue = nft.balanceInSlot(1);
        vm.stopPrank();
        assertEq(afterAddValue - beforeAddValue, 2_000_000 * ONE_UNIT);
    }

    function testRemoveValueInSlot() public {
        stdstore
            .target(address(nft))
            .sig(nft.balanceInSlot.selector)
            .with_key(1)
            .checked_write(2_000_000 * ONE_UNIT);
        vm.startPrank(owner);
        nft.removeValueInSlot(1, 1);
        uint256 afterRemoveValue = nft.balanceInSlot(1);
        vm.stopPrank();
        assertEq(afterRemoveValue, 0);
    }

    function testCannotBurnWithOnlyPool() public {
        vm.expectRevert(Constants.OnlyPool.selector);
        nft.burn(1);
    }
}

error NullAddress();
error InsufficientAllowance(uint256 allowance, uint256 balance);
error InsufficientBalance(uint256 balance, uint256 transferAmount);

contract TestUSDC is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private constant _totalSupply = 1_000_000_000 * 1e6 wei;

    string private _name;
    string private _symbol;

    uint256 private constant _decimals = 6;

    address private _owner;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _owner = msg.sender;
        _balances[msg.sender] = _totalSupply / 2;
        _balances[address(this)] = _totalSupply / 2;
        emit Transfer(address(0), msg.sender, _totalSupply / 2);
        emit Transfer(address(0), address(this), _totalSupply / 2);
    }

    function getOwner() public view returns (address) {
        return _owner;
    }

    function decimals() external pure returns (uint256) {
        return _decimals;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function totalSupply() external pure returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        external
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool) {
        uint256 currentAllowance = _allowances[sender][msg.sender];
        if (currentAllowance < amount) {
            revert InsufficientAllowance(currentAllowance, amount);
        }
        _transfer(sender, recipient, amount);
        unchecked {
            _allowances[sender][msg.sender] = currentAllowance - amount;
        }
        return true;
    }

    function transfer(address recipient, uint256 amount)
        external
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        if (sender == address(0) || recipient == address(0)) {
            revert NullAddress();
        }

        uint256 balance = _balances[sender];
        if (balance < amount) {
            revert InsufficientBalance(balance, amount);
        }

        unchecked {
            _balances[sender] = balance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function withdraw(uint256 amount) external {
        require(msg.sender == _owner);
        _transfer(address(this), _owner, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        if (owner == address(0) || spender == address(0)) {
            revert NullAddress();
        }
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function sendToMutiUser(address[] memory input, uint256 amount) external {
        if (_balances[msg.sender] < input.length * amount) {
            revert InsufficientBalance(
                _balances[msg.sender],
                input.length * amount
            );
        }

        for (uint256 i = 0; i < input.length; i++) {
            _transfer(msg.sender, input[i], amount);
        }
    }

    function claim() external {
        _transfer(address(this), msg.sender, 500_000 * 1e6);
    }
}
