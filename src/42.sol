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

    /// @notice Internal function to verify that the caller is the authorized mint guard contract.
    /// @dev This function checks if the current message sender matches the stored mintGuard address.
    /// @dev Reverts with NotMintGuard error if the caller is not the authorized mint guard.
    function _checkMintGuard() private view {
        require(msg.sender == mintGuard, NotMintGuard());
    }

    /// @notice Modifier that restricts function access to only the authorized mint guard contract.
    /// @dev Uses the internal _checkMintGuard function to verify the caller.
    /// @dev This ensures that only the designated MintGuard contract can call protected functions.
    modifier onlyMintGuard() {
        _checkMintGuard();
        _;
    }

    /// @notice Constructor that initializes the NFT42 contract with basic configuration.
    /// @dev Sets up the ERC721 token with name "42" and symbol "LT42".
    /// @param _baseMetadataUri The base URI for token metadata (e.g., "ipfs://base/").
    /// @param _mintGuard The address of the authorized MintGuard contract that can mint tokens.
    /// @param _maxTokens The maximum number of tokens that can ever be minted.
    /// @dev Reverts with ZeroAddress error if _mintGuard is address(0).
    /// @dev Reverts with InvalidMaxTokens error if _maxTokens is 0.
    constructor(string memory _baseMetadataUri, address _mintGuard, uint256 _maxTokens) ERC721("42 by LTV Protocol", "LT42") {
        require(_mintGuard != address(0), ZeroAddress());
        require(_maxTokens > 0, InvalidMaxTokens());
        baseMetadataUri = _baseMetadataUri;
        mintGuard = _mintGuard;
        MAX_TOKENS = _maxTokens;
    }

    /// @notice Mints a new NFT to the specified address.
    /// @dev Only the authorized MintGuard contract can call this function.
    /// @dev Increments the totalSupply and assigns the next sequential token ID.
    /// @param to The address that will receive the newly minted NFT.
    /// @return tokenId The unique token ID of the newly minted NFT.
    /// @dev Reverts with MaxTokensReached error if minting would exceed MAX_TOKENS.
    /// @dev Uses _safeMint to ensure the recipient can handle ERC721 tokens.
    function mint(address to) external onlyMintGuard returns (uint256 tokenId) {
        tokenId = ++totalSupply;
        require(totalSupply <= MAX_TOKENS, MaxTokensReached(MAX_TOKENS));
        _safeMint(to, tokenId);
    }

    /// @notice Returns the base URI for token metadata.
    /// @dev This function is called by the ERC721.tokenURI function to construct the full metadata URI.
    /// @dev The full URI for a token is constructed as: baseURI + tokenId
    /// @return The base metadata URI string set during contract initialization.
    // Base URI for ERC721.tokenURI
    // forge-lint: disable-next-line
    function _baseURI() internal view override returns (string memory) {
        return baseMetadataUri;
    }
}
