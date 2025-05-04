# Zeyphr Smart Contracts

This repository contains the smart contracts powering the Zeyphr NFT marketplace. It includes an admin contract for fee management and a marketplace contract for minting, listing, and purchasing NFTs — supporting both transferable and non-transferable (soulbound-style) NFTs.

---

## 📁 Contracts

### 1. `ZeyphrAdmin.sol`
- **Purpose**: Handles platform-wide configurations such as marketplace fee and fee recipient account.
- **Features**:
  - Set and update `feeAccount` (address receiving marketplace fees).
  - Set and update `feePercent` (maximum 100).
  - Only the contract owner can perform updates.

### 2. `ZeyphrMarketplace.sol`
- **Purpose**: Main marketplace contract managing minting, listing, and buying NFTs.
- **Built with**:
  - `ERC721URIStorage` (OpenZeppelin)
  - `ReentrancyGuard` (security against reentrancy attacks)
  - `IERC721Receiver` (supports safe NFT transfers)
- **Features**:
  - Mint NFTs with:
    - `transferable = true`: behaves like standard ERC721
    - `transferable = false`: soulbound logic with `quantity` & `supply`
  - Listing/unlisting NFTs
  - Purchasing NFTs (single or bulk)
  - Fee deduction on purchase (to `feeAccount`)
  - Track buyers, owners, and NFT supply

---

## 🚀 Deployment

Deployment is handled via `hardhat-deploy`.

### Prerequisites
Before running the deployment, ensure you have a `.env` file set up with the required environment variables. You can use the provided `.env.example` file as a template:

- Copy `.env.example` to `.env`:

   ```bash
   cp .env.example .env

### Scripts

#### `deploy/deploy.js`
- Deploys both `ZeyphrAdmin` and `ZeyphrMarketplace`
- Automatically verifies contracts if not on a development chain

### Example Deployment Command
```bash
npx hardhat deploy --network iota
