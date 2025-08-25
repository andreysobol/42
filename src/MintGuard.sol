// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NFT42} from "./42.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";

/// @title NFT42 MintGuard
/// @notice Simple public mint guard contract to mint and sell 42 NFTs
contract MintGuard is Ownable, ReentrancyGuard {
    struct Permission {
        address minter;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    NFT42 public immutable nft;

    /// @notice Fee per NFT in wei.
    uint256 public fee;

    /// @notice Address authorized to sign permissions.
    address public permissionSigner;

    /// @notice Tracks whether an address has already minted.
    mapping(address => bool) public mint_address;

    event Minted(address indexed buyer, uint256 indexed tokenId, uint256 pricePaid);
    event FeeUpdated(uint256 oldPrice, uint256 newPrice);
    event PermissionSignerUpdated(address indexed oldSigner, address indexed newSigner);
    event Withdrawn(address indexed to, uint256 amount);

    error InvalidFee();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error ZeroAddress();
    error InvalidSignature();
    error AlreadyMinted();

    constructor(NFT42 _nft, uint256 _fee, address _permissionSigner) Ownable(msg.sender) {
        if (address(_nft) == address(0)) revert ZeroAddress();
        if (_permissionSigner == address(0)) revert ZeroAddress();
        nft = _nft;
        if (_fee == 0) revert InvalidFee();
        fee = _fee;
        permissionSigner = _permissionSigner;
    }

    /// @notice Mint one NFT to the `perm.minter` address.
    /// @param perm Permission proving the mint is authorized.
    function mint(Permission calldata perm) external payable nonReentrant returns (uint256 tokenId) {
        if (msg.value != fee) revert IncorrectPayment(fee, msg.value);
        if (perm.minter == address(0)) revert ZeroAddress();
        verifyPermission(perm);
        if (mint_address[perm.minter]) revert AlreadyMinted();
        mint_address[perm.minter] = true;
        tokenId = nft.mint(perm.minter);
        emit Minted(msg.sender, tokenId, msg.value);
    }

    /// @notice Verify a permission signed by the configured `permissionSigner`.
    function verifyPermission(Permission calldata perm) private view returns (bool) {
        address signer = permissionSigner;
        if (signer == address(0)) revert ZeroAddress();

        // Hash the permission payload
        bytes32 digest = keccak256(abi.encodePacked(perm.minter));

        // Verify signature
        address recovered = ECDSA.recover(digest, perm.v, perm.r, perm.s);
        if (recovered != signer) revert InvalidSignature();
        return true;
    }

    /// @notice Update the permission signer address.
    function setPermissionSigner(address _newSigner) external onlyOwner nonReentrant {
        address old = permissionSigner;
        permissionSigner = _newSigner;
        emit PermissionSignerUpdated(old, _newSigner);
    }

    /// @notice Update the fee per NFT.
    function setFee(uint256 _newFee) external onlyOwner nonReentrant {
        if (_newFee == 0) revert InvalidFee();
        uint256 old = fee;
        fee = _newFee;
        emit FeeUpdated(old, _newFee);
    }

    /// @notice Withdraw full contract balance to the owner.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        (bool ok,) = payable(owner()).call{value: amount}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(owner(), amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
