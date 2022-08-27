// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeERC20.sol";
import "./IPunks.sol";
import "./IERC721.sol"; 
import "./ReentrancyGuard.sol";

// Bank primitive that allows transfer of ETH or ERC-20 from NFT to NFT, NFT to (EOA or Contract), and (EOA or Contract) to NFT
contract NFTBank is ReentrancyGuard {
    using SafeERC20 for IERC20;

    IPunks public immutable punksAddress;

    // Token (zero for ETH) address => ERC721 NFT Contract Address => NFT Token Id => balance
    mapping(address => mapping(address => mapping(uint256 => uint256))) public balances;

    constructor (address _punksAddress) {
        punksAddress = IPunks(_punksAddress);
    }

    function sendEther(address nftContractAddress, uint256 tokenId) public payable nonReentrant {
        uint256 valueReceived = msg.value;
        balances[address(0)][nftContractAddress][tokenId] = valueReceived;
    }

    function sendERC20(address tokenAddress, uint256 quantity, address nftContractAddress, uint256 tokenId) public nonReentrant {
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), quantity);
        balances[tokenAddress][nftContractAddress][tokenId] = quantity;
    }

    function sendEtherProtected(address nftContractAddress, uint256 tokenId) public payable nonReentrant {
        checkOwnership(nftContractAddress, tokenId);
        sendEther(nftContractAddress, tokenId);
    }

    function sendERC20Protected(address tokenAddress, uint256 quantity, address nftContractAddress, uint256 tokenId) public nonReentrant {
        checkOwnership(nftContractAddress, tokenId);        
        sendERC20(tokenAddress, quantity, nftContractAddress, tokenId);
    }    

    function nftSendEther(address fromNFTContractAddress, uint256 fromTokenId, uint256 quantity, address toNFTContractAddress, uint256 toTokenId) public nonReentrant {
        checkOwnership(fromNFTContractAddress, fromTokenId);
        require(balances[address(0)][fromNFTContractAddress][fromTokenId] >= quantity, "NFTBank: NFT doesn't have sufficient balance for that transfer");
        balances[address(0)][fromNFTContractAddress][fromTokenId] -= quantity;
        balances[address(0)][toNFTContractAddress][toTokenId] += quantity;
    }

    function nftSendERC20(address fromNFTContractAddress, uint256 fromTokenId, address tokenAddress, uint256 quantity, address toNFTContractAddress, uint256 toTokenId) public nonReentrant {
        checkOwnership(fromNFTContractAddress, fromTokenId);
        require(balances[tokenAddress][fromNFTContractAddress][fromTokenId] >= quantity, "NFTBank: NFT doesn't have sufficient balance for that transfer");
        balances[tokenAddress][fromNFTContractAddress][fromTokenId] -= quantity;
        balances[tokenAddress][toNFTContractAddress][toTokenId] += quantity;
    }

    function pullEther(address nftContractAddress, uint256 tokenId, uint256 quantity) public nonReentrant {
        checkOwnership(nftContractAddress, tokenId);
        require(balances[address(0)][nftContractAddress][tokenId] >= quantity, "NFTBank: NFT has insufficient balance to satisfy the withdrawal");
        balances[address(0)][nftContractAddress][tokenId] -= quantity;
        (bool success, ) = msg.sender.call{value: quantity}("");
        require(success, "NFTBank: Withdraw failed");
    }

    function pullERC20(address tokenAddress, uint256 quantity, address nftContractAddress, uint256 tokenId) public nonReentrant {
        checkOwnership(nftContractAddress, tokenId);
        require(balances[tokenAddress][nftContractAddress][tokenId] >= quantity, "NFTBank: NFT has insufficient balance to satisfy the withdrawal");
        balances[tokenAddress][nftContractAddress][tokenId] -= quantity;
        IERC20(tokenAddress).safeTransfer(msg.sender, quantity);
    }    

    /**
     * @notice Check if the message sender owns the NFT
     * @param nftAddress address of the NFT collection
     * @param tokenId token id of the NFT
     */
    function checkOwnership(address nftAddress, uint256 tokenId) internal view {
        require(msg.sender == getOwner(nftAddress, tokenId), "NFTBank: Caller is not the NFT owner");
    }

    /**
     * @notice Get NFT's owner
     * @param nftAddress address of the NFT collection
     * @param tokenId token id of the NFT
     */
    function getOwner(address nftAddress, uint256 tokenId)
        internal
        view
        returns (address)
    {
        if (nftAddress == address(punksAddress)) {
            return IPunks(punksAddress).punkIndexToAddress(tokenId);
        } else {
            return IERC721(nftAddress).ownerOf(tokenId);
        }
    }    

}
