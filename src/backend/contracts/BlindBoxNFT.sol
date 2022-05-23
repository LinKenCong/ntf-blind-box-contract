//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlindBoxNFT is Ownable, ERC721Enumerable, ReentrancyGuard {
    /// ============ Immutable storage ============

    /// @notice The cost of minting each NFT (in wei)
    uint256 public immutable MINT_COST;
    /// @notice Maximum NFT Minting Amount
    uint256 public immutable AVAILABLE_SUPPLY;
    /// @notice Maximum amount of coins minted per address
    uint256 public immutable MAX_PER_ADDRESS;

    /// ============ Mutable storage ============

    /// @notice NFT Count
    uint256 public nftCount;
    /// @notice token base uri
    string internal _baseUri;
    /// @notice token nft uri
    string internal _nftUri;
    /// @notice current state enum { initial, sale, end }
    enum BlindBoxStatus {
        INIT,
        SALE,
        END
    }
    /// @notice current state
    BlindBoxStatus private _blindBoxStatus;

    /// @notice Blind box open
    mapping(uint256 => bool) internal _blindBoxOpened;
    /// @notice Mapping from index to tokenId
    mapping(uint256 => uint256) private _indexToTokenId;

    /// ============ Events ============

    /// @notice event Open the blind box
    /// @param tokenId token id
    event OpenBlindBox(uint256 tokenId);

    /// ============ Modifier ============

    /// @notice check NFT exists
    /// @param tokenId token id
    modifier tokenExists(uint256 tokenId) {
        require(_exists(tokenId), "BlindBoxNFT: Token nonexistent");
        _;
    }

    /// @notice check Blind box not opened
    /// @param tokenId token id
    modifier blindBoxNotOpen(uint256 tokenId) {
        require(
            !_blindBoxOpened[tokenId],
            "BlindBoxNFT: Blindbox already open"
        );
        _;
    }

    // check Blind Box Activity Status
    /// @param _state BlindBox Status
    modifier blindBoxNotStateCheck(BlindBoxStatus _state) {
        require(
            _blindBoxStatus == _state,
            "BlindBoxNFT: Blindbox status error"
        );
        _;
    }

    /// ============ Constructor ============

    /// @notice Creates a new NFT distribution contract
    /// @param _NFT_NAME name of NFT
    /// @param _NFT_SYMBOL symbol of NFT
    /// @param _NFT_BASE_URI baseuri of NFT
    /// @param _AVAILABLE_SUPPLY total NFTs to sell
    /// @param _MAX_PER_ADDRESS maximum mints allowed per address
    /// @param _MINT_COST in wei per NFT
    constructor(
        string memory _NFT_NAME,
        string memory _NFT_SYMBOL,
        string memory _NFT_BASE_URI,
        uint256 _AVAILABLE_SUPPLY,
        uint256 _MAX_PER_ADDRESS,
        uint256 _MINT_COST
    ) ERC721(_NFT_NAME, _NFT_SYMBOL) {
        require(
            _MINT_COST > 0 && _AVAILABLE_SUPPLY > 0 && _MAX_PER_ADDRESS > 0,
            "BlindBoxNFT: MINT_COST must bigger than zero"
        );
        MINT_COST = _MINT_COST;
        AVAILABLE_SUPPLY = _AVAILABLE_SUPPLY;
        MAX_PER_ADDRESS = _MAX_PER_ADDRESS;
        _baseUri = _NFT_BASE_URI;
        _blindBoxStatus = BlindBoxStatus.INIT;
    }

    /// ============ Functions ============

    /// @notice Set the blind box to open
    /// @param tokenId token id
    function openBlindBox(uint256 tokenId)
        external
        tokenExists(tokenId)
        blindBoxNotOpen(tokenId)
    {
        _blindBoxOpened[tokenId] = true;
        emit OpenBlindBox(tokenId);
    }

    /// @notice mint NFT
    /// @param quantity nft count
    function mint(uint256 quantity)
        external
        payable
        nonReentrant
        blindBoxNotStateCheck(BlindBoxStatus.END)
    {
        require(quantity > 0, "BlindBoxNFT: quantity must bigger than zero");
        require(
            balanceOf(msg.sender) + quantity <= MAX_PER_ADDRESS,
            "BlindBoxNFT: Sale would exceed max quantity"
        );
        require(
            _remainCount() >= quantity,
            "BlindBoxNFT: RemainCount must bigger than amount"
        );
        require(
            msg.value >= quantity * MINT_COST,
            "BlindBoxNFT: Not enought value"
        );
        for (uint256 i = 0; i < quantity; i++) {
            uint256 random = _random(_remainCount());
            nftCount++;
            _safeMint(msg.sender, _getTokenId(random));
        }
    }

    /// ------ OnlyOwner ------

    /// @notice start selling
    function saleActive()
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.INIT)
    {
        _blindBoxStatus = BlindBoxStatus.SALE;
    }

    /// @notice end of sale
    /// @param nftUri add open blindbox uri
    function endActive(string memory nftUri)
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.SALE)
    {
        _blindBoxStatus = BlindBoxStatus.END;
        _nftUri = nftUri;
    }

    /// @notice Withdraw the contract amount
    function withdraw() external payable onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    /// ============ Developer-defined functions ============

    /// @notice Returns metadata about a token
    /// @param tokenId token id
    function tokenURI(uint256 tokenId)
        public
        view
        override
        tokenExists(tokenId)
        returns (string memory)
    {
        if (!_blindBoxOpened[tokenId]) {
            return _baseURI();
        }

        return
            bytes(_nftUri).length == 0
                ? _nftUri
                : string(abi.encodePacked(_nftUri, _toString(tokenId)));
    }

    /// @notice get unsaved id
    /// @param random random num
    function _getTokenId(uint256 random) internal returns (uint256) {
        uint256 temp = random;
        bool flag;
        uint256 tokenId = _indexToTokenId[temp];
        while (!flag) {
            if (tokenId == 0) {
                flag = true;
                tokenId = temp;
            } else {
                temp = tokenId;
                tokenId = _indexToTokenId[tokenId];
            }
        }
        _indexToTokenId[random] = _remainCount();
        return tokenId;
    }

    /// @notice baseURI
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /// @notice Converts a uint256 to its string representation
    /// @param value uint
    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /// @notice Remaining unminted quantity
    function _remainCount() internal view returns (uint256) {
        return AVAILABLE_SUPPLY - nftCount;
    }

    /// @notice get random num
    /// @param maxNum Maximum NFT Minting Amount
    function _random(uint256 maxNum) private view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(block.timestamp, maxNum, msg.sender))
            ) % maxNum;
    }
}
