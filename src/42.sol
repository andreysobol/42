// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT42 is ERC721, ERC721Enumerable {
    uint256 private _nextTokenId;
    string private _baseMetadataURI;
    address public sale;

    constructor(string memory baseMetadataURI, address sale_) ERC721("Glitch", "GLCH") {
        _baseMetadataURI = baseMetadataURI;
        sale = sale_;
    }

    modifier onlySale() {
        require(msg.sender == sale, "Not sale");
        _;
    }

    function mint(address to) external onlySale returns (uint256 tokenId) {
        require(_nextTokenId < 1024, "Maximum tokens (1024) already minted");
        tokenId = _nextTokenId;
        _nextTokenId += 1;
        _safeMint(to, tokenId);
    }

    function getBaseMetadataURI() external view returns (string memory) {
        return _baseMetadataURI;
    }

    // Base URI for ERC721.tokenURI
    function _baseURI() internal view override returns (string memory) {
        return _baseMetadataURI;
    }

    function supportsInterface(bytes4 iid) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(iid);
    }

    // Solidity >=0.8.20 requires overriding _update and _increaseBalance when combining URIStorage + Enumerable
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, amount);
    }
}
