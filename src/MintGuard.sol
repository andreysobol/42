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

    /// @notice Whether minting has been started by the owner.
    bool public mintStarted;

    event Minted(address indexed buyer, uint256 indexed tokenId);
    event MintStarted();
    event FeeUpdated(uint256 oldPrice, uint256 newPrice);
    event VoucherSignerUpdated(address indexed oldSigner, address indexed newSigner);
    event Withdrawn(address indexed to, uint256 amount);

    error InvalidFee();
    error IncorrectPayment(uint256 expected, uint256 actual);
    error ZeroAddress();
    error InvalidSignature();
    error AlreadyMinted();
    error WithdrawFailed();
    error MintNotStarted();

    /// @notice Constructor that disables initializers to prevent direct initialization.
    /// @dev This is required for upgradeable contracts to prevent initialization outside of the proxy.
    /// @dev The actual initialization should be done through the initialize function.
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the MintGuard contract with required parameters.
    /// @dev This function sets up the upgradeable contract with initial configuration.
    /// @param _fee The fee in wei required to mint one NFT.
    /// @param _voucherSigner The address authorized to sign minting vouchers.
    /// @param _owner The address that will be set as the contract owner.
    /// @dev Reverts with ZeroAddress error if _voucherSigner is address(0).
    /// @dev Reverts with InvalidFee error if _fee is 0.
    /// @dev Initializes ReentrancyGuard and Ownable with the provided owner.
    function initialize(uint256 _fee, address _voucherSigner, address _owner) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init(_owner);
        require(_voucherSigner != address(0), ZeroAddress());
        require(_fee != 0, InvalidFee());
        fee = _fee;
        voucherSigner = _voucherSigner;
    }

    /// @notice Mint one NFT to the `voucher.minter` address using a signed voucher.
    /// @dev This function allows public minting with proper authorization and payment.
    /// @param voucher Voucher containing the minter address and cryptographic signature proving authorization.
    /// @return tokenId The unique token ID of the newly minted NFT.
    /// @dev Reverts with MintNotStarted error if minting hasn't been started by the owner.
    /// @dev Reverts with IncorrectPayment error if the sent value doesn't match the required fee.
    /// @dev Reverts with ZeroAddress error if voucher.minter is address(0).
    /// @dev Reverts with InvalidSignature error if the voucher signature is invalid.
    /// @dev Reverts with AlreadyMinted error if the minter has already minted an NFT.
    /// @dev Reverts with ZeroAddress error if the NFT contract is not set.
    /// @dev Emits Minted event upon successful minting.
    function mint(Voucher calldata voucher) external payable nonReentrant returns (uint256 tokenId) {
        require(mintStarted, MintNotStarted());
        require(msg.value == fee, IncorrectPayment(fee, msg.value));
        require(voucher.minter != address(0), ZeroAddress());
        verifyVoucher(voucher);
        require(!mintAddress[voucher.minter], AlreadyMinted());
        mintAddress[voucher.minter] = true;
        require(address(nft) != address(0), ZeroAddress());
        tokenId = nft.mint(voucher.minter);
        emit Minted(msg.sender, tokenId);
    }

    /// @notice Start minting and optionally mint NFTs to an address - only owner can call this function.
    /// @dev This function enables public minting and optionally performs admin minting in the same transaction.
    /// @param to The address to mint NFTs to (can be address(0) to skip admin minting).
    /// @param amount The number of NFTs to mint (ignored if to is address(0)).
    /// @dev Always sets mintStarted to true and emits MintStarted event.
    /// @dev If to is not address(0) and amount > 0, performs admin minting to the specified address.
    /// @dev Reverts with ZeroAddress error if NFT contract is not set when attempting admin minting.
    /// @dev Emits Minted event for each NFT minted during admin minting.
    function start(address to, uint256 amount) external onlyOwner nonReentrant {
        mintStarted = true;
        emit MintStarted();

        if (to != address(0) && amount > 0) {
            require(address(nft) != address(0), ZeroAddress());

            for (uint256 i = 0; i < amount; i++) {
                uint256 tokenId = nft.mint(to);
                emit Minted(to, tokenId);
            }
        }
    }

    /// @notice Set the NFT contract address - only owner can call this function.
    /// @dev This function allows the owner to set or update the NFT contract that will be used for minting.
    /// @param _nft The address of the NFT42 contract to use for minting.
    /// @dev Reverts with ZeroAddress error if _nft is address(0).
    /// @dev This function is typically called after contract deployment to link the MintGuard with the NFT contract.
    function setNft(NFT42 _nft) external onlyOwner {
        require(address(_nft) != address(0), ZeroAddress());
        nft = _nft;
    }

    /// @notice Verify a voucher signed by the configured `voucherSigner`.
    /// @dev This function validates the cryptographic signature of a minting voucher.
    /// @param voucher The voucher containing the minter address and signature components (v, r, s).
    /// @return true if the signature is valid and matches the configured voucher signer.
    /// @dev Reverts with ZeroAddress error if voucherSigner is not set.
    /// @dev Reverts with InvalidSignature error if the signature doesn't match the expected signer.
    /// @dev The voucher payload is hashed using keccak256(abi.encodePacked(voucher.minter)).
    /// @dev forge-lint: disable-next-line (comment preserved for linting configuration)
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

    /// @notice Update the voucher signer address - only owner can call this function.
    /// @dev This function allows the owner to change the address authorized to sign minting vouchers.
    /// @param _newSigner The new address that will be authorized to sign vouchers.
    /// @dev Emits VoucherSignerUpdated event with the old and new signer addresses.
    /// @dev This function is protected by onlyOwner and nonReentrant modifiers.
    function setVoucherSigner(address _newSigner) external onlyOwner nonReentrant {
        address old = voucherSigner;
        voucherSigner = _newSigner;
        emit VoucherSignerUpdated(old, _newSigner);
    }

    /// @notice Update the fee per NFT - only owner can call this function.
    /// @dev This function allows the owner to change the fee required to mint one NFT.
    /// @param _newFee The new fee in wei required to mint one NFT.
    /// @dev Reverts with InvalidFee error if _newFee is 0.
    /// @dev Emits FeeUpdated event with the old and new fee values.
    /// @dev This function is protected by onlyOwner and nonReentrant modifiers.
    function setFee(uint256 _newFee) external onlyOwner nonReentrant {
        require(_newFee != 0, InvalidFee());
        uint256 old = fee;
        fee = _newFee;
        emit FeeUpdated(old, _newFee);
    }

    /// @notice Withdraw full contract balance to the owner - only owner can call this function.
    /// @dev This function allows the owner to withdraw all ETH accumulated from minting fees.
    /// @dev Reverts with WithdrawFailed error if the transfer to the owner fails.
    /// @dev Emits Withdrawn event with the owner address and amount withdrawn.
    /// @dev This function is protected by onlyOwner and nonReentrant modifiers.
    function withdraw() external onlyOwner nonReentrant {
        uint256 amount = address(this).balance;
        (bool ok,) = payable(owner()).call{value: amount}("");
        require(ok, WithdrawFailed());
        emit Withdrawn(owner(), amount);
    }

    /// @notice Receive function to accept ETH payments.
    /// @dev This function allows the contract to receive ETH directly.
    /// @dev ETH received through this function will be added to the contract's balance.
    receive() external payable {}

    /// @notice Fallback function to accept ETH payments and handle unknown function calls.
    /// @dev This function is called when a transaction is sent to the contract with no data or unknown function selector.
    /// @dev ETH sent through this function will be added to the contract's balance.
    fallback() external payable {}
}
