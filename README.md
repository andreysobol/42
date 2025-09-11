# 42

## IPFS CIDs
```
mainnet QmXTn6YvXZgNmNzyBN19RgYgpG6YeZNnTwo1zWbHSb8x5b

sepolia QmbtxQySbQcGxMUxofMhoxdevKeQMjE9i6xuWsSoLnJbrw
```

## IPFS Upload Instructions

### Mainnet Upload

#### Upload images directory to IPFS (recursively):
```bash
cd content/mainnet/images
ipfs add -r .
```

#### Upload metadata directory to IPFS (recursively):
```bash
cd content/mainnet/metadata
ipfs add -r .
```

### Testnet (Sepolia) Upload

#### Upload images directory to IPFS (recursively):
```bash
cd content/sepolia/images
ipfs add -r .
```

#### Upload metadata directory to IPFS (recursively):
```bash
cd content/sepolia/metadata
ipfs add -r .
```

**Note:** Use the resulting CID as the constructor `baseMetadataURI`. Can be changed in `script/DeployGlitchNft.s.sol` before deploying.

### Folder Structure
- `content/mainnet/` - Mainnet deployment content
  - `images/` - NFT images (1.png to 1024.png)
  - `metadata/` - NFT metadata files (1 to 1024)
- `content/sepolia/` - Sepolia testnet content
  - `images/` - NFT images (1.png to 128.png)
  - `metadata/` - NFT metadata files (1 to 128)

