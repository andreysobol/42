// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "openzeppelin-contracts/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract NFT42 is ERC721, ERC721Enumerable {
    uint256 private nextTokenId;
    string private baseMetadataURI;
    // change name to mintGuard
    address public mintGuard;
    uint256 public immutable maxTokens;

    constructor(string memory _baseMetadataURI, address _mintGuard, uint256 _maxTokens) ERC721("Glitch", "GLCH") {
        baseMetadataURI = _baseMetadataURI;
        mintGuard = _mintGuard;
        maxTokens = _maxTokens;
    }

    modifier onlyMintGuard() {
        require(msg.sender == mintGuard, "Not mintGuard");
        _;
    }

    function mint(address to) external onlyMintGuard returns (uint256 tokenId) {
        nextTokenId += 1;
        require(nextTokenId <= maxTokens, "Maximum tokens already minted");
        tokenId = nextTokenId;
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
