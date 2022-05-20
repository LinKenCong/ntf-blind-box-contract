//SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BlindBoxNFT is Ownable, ERC721URIStorage {
    using Counters for Counters.Counter;

    // tokenid 计数
    Counters.Counter public _tokenIdCounter;
    // 铸造者
    address private _minter;
    // 盲盒图片的uri(未开启)
    string private _blindBoxURI;
    // 图片的uri(开启)
    string private _nftURI;

    // 盲盒 价格
    uint256 private _blindBoxPrice;

    // 当前盲盒活动状态
    enum BlindBoxStatus {
        START,
        SALE,
        END
    }
    BlindBoxStatus private _blindBoxStatus;

    // 盲盒打开状态
    mapping(uint256 => bool) private _blindBoxOpened;

    // 监听 打开盲盒
    event OpenBlindBox(uint256 tokenId);
    // 监听 制作盲盒
    event MintBlindBoxNFT(uint256 oldTotalSupply, uint256 newTotalSupply);

    // 检测 NFT存在
    modifier exists(uint256 tokenId) {
        require(_exists(tokenId), "BlindBoxNFT: Token nonexistent");
        _;
    }
    // 检测 只有铸造者
    modifier onlyMinter() {
        require(msg.sender == _minter, "BlindBoxNFT: Auth failds");
        _;
    }

    // 检测 盲盒未被打开
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

    constructor(
        address minter,
        string memory name,
        string memory symbol,
        string memory nftURI,
        string memory blindBoxURI
    ) ERC721(name, symbol) {
        _minter = minter;
        _nftURI = nftURI;
        _blindBoxURI = blindBoxURI;
        _blindBoxStatus = BlindBoxStatus.START;
    }

    // 制作盲盒NFT
    function safeMint(address _to, string memory _uri)
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.START)
    {
        uint256 __tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(_to, __tokenId);
        _setTokenURI(__tokenId, _uri);
        emit MintBlindBoxNFT(__tokenId, _tokenIdCounter.current());
    }

    // 设置盲盒开启
    function setOpenBlindBox(uint256 _tokenId)
        external
        onlyMinter
        exists(_tokenId)
        blindBoxNotOpen(_tokenId)
    {
        _blindBoxOpened[_tokenId] = true;
        emit OpenBlindBox(_tokenId);
    }

    // 设置 盲盒活动开始售卖
    function setBlindBoxSale(uint256 _price)
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.START)
    {
        _blindBoxStatus = BlindBoxStatus.SALE;
        _blindBoxPrice = _price;
    }

    // 设置 盲盒活动结束
    function setBlindBoxEnd()
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.SALE)
    {
        _blindBoxStatus = BlindBoxStatus.END;
    }

    // 合约拥有者 设置所有盲盒开启
    function setOpenAllBlindBox()
        external
        onlyOwner
        blindBoxNotStateCheck(BlindBoxStatus.END)
    {
        for (uint256 i = 0; i < _tokenIdCounter.current(); i++) {
            if (_exists(i) && !_blindBoxOpened[i]) {
                _blindBoxOpened[i] = true;
                emit OpenBlindBox(i);
            }
        }
    }

    // 查看NFT URI
    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721URIStorage)
        exists(_tokenId)
        returns (string memory)
    {
        if (isBlindBoxOpened(_tokenId)) {
            return super.tokenURI(_tokenId);
        } else {
            return _blindBoxURI;
        }
    }

    // 查看盲盒开启状态
    function isBlindBoxOpened(uint256 _tokenId) public view returns (bool) {
        return _blindBoxOpened[_tokenId];
    }

    // NFT URI
    function _baseURI() internal view override returns (string memory) {
        return _nftURI;
    }

    // 销毁
    function _burn(uint256 _tokenId)
        internal
        override(ERC721URIStorage)
        exists(_tokenId)
    {
        super._burn(_tokenId);
    }
}
