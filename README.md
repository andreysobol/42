# 42

42. A curatorless NFT collection.

A non-upgradable **ERC-721** collection with an on-chain **`baseMetadataURI`** pointing to **IPFS**. Built with **Foundry**. 

**Features:**
- ERC-721 with immutable `baseMetadataURI` set at deploy time
- Limited supply (**1024** maximum)
- Fixed mint fee
- Whitelist only

## IPFS CIDs

- **Mainnet metadata CID:** `QmXTn6YvXZgNmNzyBN19RgYgpG6YeZNnTwo1zWbHSb8x5b`
- **Sepolia metadata CID:** `QmbtxQySbQcGxMUxofMhoxdevKeQMjE9i6xuWsSoLnJbrw`
- **Content supply:** mainnet `1..1024`, sepolia `1..128`
- **Token URI shape:** `ipfs://<metadataCID>/<tokenId>`

---

## IPFS pipeline

1. **Upload images** (recursive):
   ```bash
   cd content/mainnet/images
   ipfs add -r .
   # Save CID if you reference images by their own tree
   ```

2. **Upload metadata** (recursive):
   ```bash
   cd content/mainnet/metadata
   ipfs add -r .
   # This CID becomes your baseMetadataURI
   ```

3. **Upload images for Sepolia** (recursive):
   ```bash
   cd content/sepolia/images
   ipfs add -r .
   # Save CID if you reference images by their own tree
   ```

4. **Upload metadata for Sepolia** (recursive):
   ```bash
   cd content/sepolia/metadata
   ipfs add -r .
   # This CID becomes your baseMetadataURI for Sepolia
   ```

---

## Build & test

```bash
forge build
forge test -vv
```

---

## Deploy & verify

### Export your environment variables:

```bash
export RPC_URL=""
export ETH_FROM="0xYourDeployer"
export PRIVATE_KEY="0xYourPrivateKey"     # or Foundry keystore
export ETHERSCAN_API_KEY="..."

# MintGuard deployment parameters
export FEE="1000000000000000000"          # 1 ETH in wei
export VOUCHER_SIGNER="0xYourSigner"
export PROXY_OWNER="0xYourProxyOwner"
export MINT_GUARD_OWNER="0xYourMintGuardOwner"

# NFT42 deployment parameters
export BASE_METADATA_URI="ipfs://QmYourMetadataCID/"  # Your IPFS metadata CID
export MAX_TOKENS="1024"                              # Maximum number of tokens
export MINT_GUARD_ADDRESS="0xYourMintGuardAddress"    # Set after MintGuard deployment
```

### Deploy MintGuard first

```bash
# Deploy MintGuard
forge script script/DeployMintGuard.s.sol \
  --rpc-url $RPC_URL --broadcast \
  --verify --etherscan-api-key $ETHERSCAN_API_KEY

# Update MINT_GUARD_ADDRESS with the deployed address
export MINT_GUARD_ADDRESS="0xDeployedMintGuardAddress"
```

### Deploy NFT42

```bash
# Deploy NFT42
forge script script/DeployNFT42.s.sol \
  --rpc-url $RPC_URL --broadcast \
  --verify --etherscan-api-key $ETHERSCAN_API_KEY
```