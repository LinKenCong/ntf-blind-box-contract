// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTToken is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    /// ============ Mutable storage ============
    Counters.Counter private _tokenIdCounter;

    string private _baseUri;

    /// ============ Events ============

    event MintNFT(uint256 tokenId);

    /// ============ Constructor ============

    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        string memory _NFT_BASE_URI
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) {
        _baseUri = _NFT_BASE_URI;
    }

    /// ============ Functions ============

    /// ------ OnlyOwner ------
    function safeMint(address to, string memory uri) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit MintNFT(tokenId);
    }

    /// ============ Developer-defined functions ============

    /// @notice get tokenURI
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /// @notice baseURI
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /// @notice burn Token
    function _burn(uint256 tokenId) internal override {
        super._burn(tokenId);
    }
}
