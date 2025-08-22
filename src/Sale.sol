// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {NFT42} from "./42.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

struct Permission {
    address minter;
    uint32 key;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/// @title NFT42 Sale
/// @notice Simple public sale contract to mint and sell Glitch NFTs for a fixed price.
contract Sale {
    /// @dev Basic ownable pattern w/o external deps.
    address public owner;
    NFT42 public immutable nft;

    /// @notice Price per NFT in wei.
    uint256 public price;

    /// @notice Address authorized to sign permissions.
    address public permissionSigner;

    /// @notice Tracks whether a permission key has been redeemed.
    mapping(uint32 => bool) public redeemed_key;

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
    error KeyAlreadyRedeemed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(NFT42 nft_, uint256 price_, address permissionSigner_) {
        if (address(nft_) == address(0)) revert ZeroAddress();
        if (permissionSigner_ == address(0)) revert ZeroAddress();
        owner = msg.sender;
        nft = nft_;
        if (price_ == 0) revert InvalidPrice();
        price = price_;
        permissionSigner = permissionSigner_;
    }

    /// @notice Purchase and mint one NFT to the `perm.minter` address.
    /// @param perm Permission proving the mint is authorized.
    function buy(Permission calldata perm) external payable returns (uint256 tokenId) {
        if (msg.value != price) revert IncorrectPayment(price, msg.value);
        if (perm.minter == address(0)) revert ZeroAddress();
        if (redeemed_key[perm.key]) revert KeyAlreadyRedeemed();
        if (!verifyPermission(perm)) revert IncorrectPermission();
        redeemed_key[perm.key] = true;
        tokenId = nft.mint(perm.minter);
        emit Purchased(msg.sender, tokenId, msg.value);
    }

    /// @notice Verify a permission signed by the configured `permissionSigner`.
    function verifyPermission(
        Permission calldata perm
    ) private view returns (bool) {
        address signer = permissionSigner;
        if (signer == address(0)) return false;

        // Hash the permission payload
        bytes32 digest = keccak256(abi.encodePacked(perm.minter, perm.key));

        // Verify signature
        address recovered = ECDSA.recover(digest, perm.v, perm.r, perm.s);
        return recovered == signer;
    }

    /// @notice Update the permission signer address.
    function setPermissionSigner(address newSigner) external onlyOwner {
        address old = permissionSigner;
        permissionSigner = newSigner;
        emit PermissionSignerUpdated(old, newSigner);
    }

    /// @notice Update the price per NFT.
    function setPrice(uint256 newPrice) external onlyOwner {
        if (newPrice == 0) revert InvalidPrice();
        uint256 old = price;
        price = newPrice;
        emit PriceUpdated(old, newPrice);
    }

    /// @notice Transfer ownership to a new account.
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    /// @notice Withdraw full contract balance to the owner.
    function withdraw() external onlyOwner {
        uint256 amount = address(this).balance;
        (bool ok, ) = payable(owner).call{value: amount}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(owner, amount);
    }

    receive() external payable {}
}