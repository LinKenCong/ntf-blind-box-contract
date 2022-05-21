//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlindBoxNFT is Ownable, ERC721Enumerable, ReentrancyGuard {
    /// ============ Immutable storage ============

    /// @notice 铸造每个NFT的成本 (in wei)
    uint256 public immutable MINT_COST;
    /// @notice 最大NFT铸造量
    uint256 public immutable AVAILABLE_SUPPLY;
    /// @notice 每个地址最大铸币量
    uint256 public immutable MAX_PER_ADDRESS;

    /// ============ Mutable storage ============

    /// @notice NFT 计数
    uint256 public nftCount;
    /// @notice token base uri
    string internal _baseUri;
    /// @notice token nft uri
    string internal _nftUri;
    /// @notice 当前状态 枚举 { 初始,售卖,结束 }
    enum BlindBoxStatus {
        INIT,
        SALE,
        END
    }
    /// @notice 当前状态
    BlindBoxStatus private _blindBoxStatus;

    /// @notice 盲盒开启状态
    mapping(uint256 => bool) internal _blindBoxOpened;
    /// @notice Mapping from index to tokenId
    mapping(uint256 => uint256) private _indexToTokenId;

    /// ============ Events ============

    /// @notice 监听 打开盲盒
    event OpenBlindBox(uint256 tokenId);

    /// ============ Modifier ============

    /// @notice 检测 NFT存在
    modifier tokenExists(uint256 tokenId) {
        require(_exists(tokenId), "BlindBoxNFT: Token nonexistent");
        _;
    }

    /// @notice 检测 盲盒未被打开
    modifier blindBoxNotOpen(uint256 tokenId) {
        require(
            !_blindBoxOpened[tokenId],
            "BlindBoxNFT: Blindbox already open"
        );
        _;
    }

    // 检测 盲盒活动 状态
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

    /// @notice 设置盲盒开启
    function openBlindBox(uint256 _tokenId)
        external
        tokenExists(_tokenId)
        blindBoxNotOpen(_tokenId)
    {
        _blindBoxOpened[_tokenId] = true;
        emit OpenBlindBox(_tokenId);
    }

    /// @notice mint NFT
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

    /// @notice 开始售卖
    function saleActive()
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.INIT)
    {
        _blindBoxStatus = BlindBoxStatus.SALE;
    }

    /// @notice 结束售卖
    function endActive(string memory nftUri)
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.SALE)
    {
        _blindBoxStatus = BlindBoxStatus.END;
        _nftUri = nftUri;
    }

    /// @notice 提取合约金额
    function withdraw() external payable onlyOwner nonReentrant {
        payable(owner()).transfer(address(this).balance);
    }

    /// ============ Developer-defined functions ============

    /// @notice Returns metadata about a token
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

    /// @notice 获取未储存的id
    function _getTokenId(uint256 random) internal returns (uint256) {
        // 随机数
        uint256 temp = random;
        // false
        bool flag;
        // 索引获取id
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
    function _toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

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

    /// @notice 剩余未铸造数量
    function _remainCount() internal view returns (uint256) {
        return AVAILABLE_SUPPLY - nftCount;
    }

    /// @notice get random num
    function _random(uint256 maxNum) private view returns (uint256) {
        return
            uint256(
                keccak256(abi.encodePacked(block.timestamp, maxNum, msg.sender))
            ) % maxNum;
    }
}
