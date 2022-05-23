// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Token is ERC20 {
    constructor(
        string memory _TOKEN_NAME,
        string memory _TOKEN_SYMBOL,
        uint256 _TOKEN_AMOUNT
    ) ERC20(_TOKEN_NAME, _TOKEN_SYMBOL) {
        _mint(msg.sender, _TOKEN_AMOUNT * 10**decimals());
    }
}
