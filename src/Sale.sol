// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NFT42} from "./42.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

/// @title NFT42 MintGuard
/// @notice Simple public mint guard contract to mint and sell 42 NFTs
contract MintGuard {
    struct Permission {
        address minter;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    /// @dev Basic ownable pattern w/o external deps.

    address public owner;
    NFT42 public immutable nft;

    /// @notice Price per NFT in wei.
    uint256 public price;

    /// @notice Address authorized to sign permissions.
    address public permissionSigner;

    /// @notice Tracks whether an address has already minted.
    mapping(address => bool) public mint_address;

    event Purchased(address indexed buyer, uint256 indexed tokenId, uint256 pricePaid);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event PermissionSignerUpdated(address indexed oldSigner, address indexed newSigner);
    event Withdrawn(address indexed to, uint256 amount);

    error NotOwner();
    error InvalidPrice();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error ZeroAddress();
    error InvalidSignature();
    error IncorrectPermission();
    error AlreadyMinted();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(NFT42 _nft, uint256 _price, address _permissionSigner) {
        if (address(_nft) == address(0)) revert ZeroAddress();
        if (_permissionSigner == address(0)) revert ZeroAddress();
        owner = msg.sender;
        nft = _nft;
        if (_price == 0) revert InvalidPrice();
        price = _price;
        permissionSigner = _permissionSigner;
    }

    /// @notice Purchase and mint one NFT to the `perm.minter` address.
    /// @param perm Permission proving the mint is authorized.
    function buy(Permission calldata perm) external payable returns (uint256 tokenId) {
        if (msg.value != price) revert IncorrectPayment(price, msg.value);
        if (perm.minter == address(0)) revert ZeroAddress();
        if (!verifyPermission(perm)) revert IncorrectPermission();
        if (mint_address[perm.minter]) revert AlreadyMinted();
        tokenId = nft.mint(perm.minter);
        mint_address[perm.minter] = true;
        emit Purchased(msg.sender, tokenId, msg.value);
    }

    /// @notice Verify a permission signed by the configured `permissionSigner`.
    function verifyPermission(Permission calldata perm) private view returns (bool) {
        address signer = permissionSigner;
        if (signer == address(0)) return false;

        // Hash the permission payload
        bytes32 digest = keccak256(abi.encodePacked(perm.minter));

        // Verify signature
        address recovered = ECDSA.recover(digest, perm.v, perm.r, perm.s);
        return recovered == signer;
    }

    /// @notice Update the permission signer address.
    function setPermissionSigner(address _newSigner) external onlyOwner {
        address old = permissionSigner;
        permissionSigner = _newSigner;
        emit PermissionSignerUpdated(old, _newSigner);
    }

    /// @notice Update the price per NFT.
    function setPrice(uint256 _newPrice) external onlyOwner {
        if (_newPrice == 0) revert InvalidPrice();
        uint256 old = price;
        price = _newPrice;
        emit PriceUpdated(old, _newPrice);
    }

    /// @notice Transfer ownership to a new account.
    function transferOwnership(address _newOwner) external onlyOwner {
        owner = _newOwner;
    }

    /// @notice Withdraw full contract balance to the owner.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok,) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(owner, amount);
    }

    receive() external payable {}
}
