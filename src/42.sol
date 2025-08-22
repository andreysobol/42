// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT42 is ERC721, ERC721Enumerable {
    uint256 private nextTokenId;
    string private baseMetadataURI;
    address public sale;

    constructor(string memory _baseMetadataURI, address _sale) ERC721("Glitch", "GLCH") {
        baseMetadataURI = _baseMetadataURI;
        sale = _sale;
    }

    modifier onlySale() {
        require(msg.sender == sale, "Not sale");
        _;
    }

    function mint(address to) external onlySale returns (uint256 tokenId) {
        require(nextTokenId < 1024, "Maximum tokens (1024) already minted");
        tokenId = nextTokenId;
        nextTokenId += 1;
        _safeMint(to, tokenId);
    }

    function getBaseMetadataURI() external view returns (string memory) {
        return baseMetadataURI;
    }

    // Base URI for ERC721.tokenURI
    function _baseURI() internal view override returns (string memory) {
        return baseMetadataURI;
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
