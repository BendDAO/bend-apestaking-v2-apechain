// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

interface IApeCoinStakingCallback {
    function executeCallback(bytes32 guid) external;
}

/**
 * @title MintableERC721
 * @dev ERC721 minting logic
 */
contract MintableERC721 is ERC721Enumerable, Ownable {
    event ReadWithCallback(bytes32 guid, uint256[] tokenIds);
    event ExecuteCallback(bytes32 guid);

    string public baseURI;
    mapping(address => uint256) public mintCounts;
    uint256 public maxSupply;
    uint256 public maxTokenId;
    mapping(uint256 => bool) public lockedTokens;
    bool public disableTransfer;
    uint256 public nextReadId;

    constructor(string memory name, string memory symbol) Ownable() ERC721(name, symbol) {
        maxSupply = 10000;
        maxTokenId = maxSupply - 1;
        baseURI = "https://MintableERC721/";
    }

    /**
     * @dev Function to mint tokens
     * @param tokenId The id of tokens to mint.
     * @return A boolean that indicates if the operation was successful.
     */
    function mint(uint256 tokenId) public returns (bool) {
        require(tokenId <= maxTokenId, "exceed max token id");
        require(totalSupply() + 1 <= maxSupply, "exceed max supply");

        mintCounts[_msgSender()] += 1;
        require(mintCounts[_msgSender()] <= 100, "exceed mint limit");

        _mint(_msgSender(), tokenId);
        return true;
    }

    function privateMint(address to, uint256 tokenId) public onlyOwner returns (bool) {
        require(tokenId <= maxTokenId, "exceed max token id");
        require(totalSupply() + 1 <= maxSupply, "exceed max supply");

        _mint(to, tokenId);
        return true;
    }

    function privateBurn(uint256 tokenId) public onlyOwner {
        require(_exists(tokenId), "token does not exist");

        _burn(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory baseURI_) public onlyOwner {
        baseURI = baseURI_;
    }

    function setMaxSupply(uint256 maxSupply_) public onlyOwner {
        maxSupply = maxSupply_;
    }

    function setMaxTokenId(uint256 maxTokenId_) public onlyOwner {
        maxTokenId = maxTokenId_;
    }

    function executeCallback(address apeCoinStaking_, bytes32 guid_) public {
        IApeCoinStakingCallback(apeCoinStaking_).executeCallback(guid_);

        emit ExecuteCallback(guid_);
    }

    function readWithCallback(
        uint256[] calldata tokenIds,
        uint32[] calldata eids,
        uint128 callbackGasLimit
    ) public payable returns (bytes32) {
        tokenIds;
        eids;
        callbackGasLimit;

        bytes32 guid = getNextGUID();

        nextReadId += 1;

        emit ReadWithCallback(guid, tokenIds);

        return guid;
    }

    function getNextGUID() public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), nextReadId));
    }

    function locked(uint256 tokenId) public view returns (bool) {
        return lockedTokens[tokenId];
    }

    function setLocked(uint256 tokenId, bool flag) public onlyOwner {
        lockedTokens[tokenId] = flag;
    }

    function setDisableTransfer(bool flag) public onlyOwner {
        disableTransfer = flag;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        from;
        to;
        firstTokenId;
        batchSize;

        require(!disableTransfer, "transfer disabled");
    }
}
