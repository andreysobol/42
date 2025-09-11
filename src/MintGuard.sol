// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {NFT42} from "./42.sol";
import {ECDSA} from "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";

/// @title NFT42 MintGuard
/// @notice Simple public mint guard contract to mint and sell 42 NFTs
contract MintGuard is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    struct Voucher {
        address minter;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    NFT42 public nft;

    /// @notice Fee per NFT in wei.
    uint256 public fee;

    /// @notice Address authorized to sign vouchers.
    address public voucherSigner;

    /// @notice Tracks whether an address has already minted.
    mapping(address => bool) public mintAddress;

    event Minted(address indexed buyer, uint256 indexed tokenId, uint256 pricePaid);
    event FeeUpdated(uint256 oldPrice, uint256 newPrice);
    event VoucherSignerUpdated(address indexed oldSigner, address indexed newSigner);
    event Withdrawn(address indexed to, uint256 amount);

    error InvalidFee();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error ZeroAddress();
    error InvalidSignature();
    error AlreadyMinted();
    error WithdrawFailed();

    constructor() {
        _disableInitializers();
    }

    function initialize(uint256 _fee, address _voucherSigner, address _owner) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        require(_voucherSigner != address(0), ZeroAddress());
        require(_fee != 0, InvalidFee());
        fee = _fee;
        voucherSigner = _voucherSigner;
    }

    /// @notice Mint one NFT to the `voucher.minter` address.
    /// @param voucher Voucher proving the mint is authorized.
    function mint(Voucher calldata voucher) external payable nonReentrant returns (uint256 tokenId) {
        require(msg.value == fee, IncorrectPayment(fee, msg.value));
        require(voucher.minter != address(0), ZeroAddress());
        verifyVoucher(voucher);
        require(!mintAddress[voucher.minter], AlreadyMinted());
        mintAddress[voucher.minter] = true;
        require(address(nft) != address(0), ZeroAddress());
        tokenId = nft.mint(voucher.minter);
        emit Minted(msg.sender, tokenId, msg.value);
    }

    function setNft(NFT42 _nft) external onlyOwner {
        require(address(_nft) != address(0), ZeroAddress());
        nft = _nft;
    }

    /// @notice Verify a voucher signed by the configured `voucherSigner`.
    function verifyVoucher(Voucher calldata voucher) private view returns (bool) {
        address signer = voucherSigner;
        require(signer != address(0), ZeroAddress());

        // Hash the voucher payload
        // forge-lint: disable-next-line
        bytes32 digest = keccak256(abi.encodePacked(voucher.minter));

        // Verify signature
        address recovered = ECDSA.recover(digest, voucher.v, voucher.r, voucher.s);
        require(recovered == signer, InvalidSignature());
        return true;
    }

    /// @notice Update the voucher signer address.
    function setVoucherSigner(address _newSigner) external onlyOwner nonReentrant {
        address old = voucherSigner;
        voucherSigner = _newSigner;
        emit VoucherSignerUpdated(old, _newSigner);
    }

    /// @notice Update the fee per NFT.
    function setFee(uint256 _newFee) external onlyOwner nonReentrant {
        require(_newFee != 0, InvalidFee());
        uint256 old = fee;
        fee = _newFee;
        emit FeeUpdated(old, _newFee);
    }

    /// @notice Withdraw full contract balance to the owner.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        (bool ok,) = payable(owner()).call{value: amount}("");
        require(ok, WithdrawFailed());
        emit Withdrawn(owner(), amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
