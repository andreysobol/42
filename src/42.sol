// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

contract NFT42 is ERC721 {
    uint256 public totalSupply;
    string private baseMetadataUri;
    address public mintGuard;
    uint256 public immutable MAX_TOKENS;

    error NotMintGuard();
    error MaxTokensReached(uint256 maxTokens);
    error ZeroAddress();
    error InvalidMaxTokens();

    function _checkMintGuard() private view {
        require(msg.sender == mintGuard, NotMintGuard());
    }

    modifier onlyMintGuard() {
        _checkMintGuard();
        _;
    }

    constructor(string memory _baseMetadataUri, address _mintGuard, uint256 _maxTokens) ERC721("42", "FTW") {
        require(_mintGuard != address(0), ZeroAddress());
        require(_maxTokens > 0, InvalidMaxTokens());
        baseMetadataUri = _baseMetadataUri;
        mintGuard = _mintGuard;
        MAX_TOKENS = _maxTokens;
    }

    function mint(address to) external onlyMintGuard returns (uint256 tokenId) {
        tokenId = ++totalSupply;
        require(totalSupply <= MAX_TOKENS, MaxTokensReached(MAX_TOKENS));
        _safeMint(to, tokenId);
    }

    // Base URI for ERC721.tokenURI
    // forge-lint: disable-next-line
    function _baseURI() internal view override returns (string memory) {
        return baseMetadataUri;
    }
}
