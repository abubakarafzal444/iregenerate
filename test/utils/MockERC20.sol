// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { ERC20 } from "solmate/tokens/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK", 6) {}

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}