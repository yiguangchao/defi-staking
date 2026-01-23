# 🏦 DeFi Staking & Yield Aggregator (ERC-4626)

![Solidity](https://img.shields.io/badge/Solidity-%5E0.8.20-363636?style=flat&logo=solidity)
![Go](https://img.shields.io/badge/Go-1.21+-00ADD8?style=flat&logo=go)
![React](https://img.shields.io/badge/React-18.x-61DAFB?style=flat&logo=react)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-336791?style=flat&logo=postgresql)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A production-grade, full-stack DeFi Vault platform built on the **ERC-4626 standard**. 

This project seamlessly integrates a Smart Contract Vault, a high-performance Go Indexer, and a React-based DApp. It provides users with a secure and real-time yield farming experience by routing idle assets to **Aave V3** to generate passive income.

## ✨ Key Features

* **💎 ERC-4626 Standardized Vault**: Fully compliant with the Tokenized Vault Standard, utilizing OpenZeppelin V5 for robust inflation attack resistance (Virtual Shares).
* **📈 Real Yield via Aave V3**: Deposits are automatically routed to Aave V3 through a dedicated `AaveStrategy`. Features dynamic `PoolAddressesProvider` for resistance against Aave protocol upgrades.
* **⚡ High-Performance Go Indexer**: A backend listener using `go-ethereum` and WebSockets to capture on-chain events (`Deposit`, `Withdraw`) in real-time.
* **🤖 Smart Reconciler**: An automated background worker that polls the blockchain every 5 seconds to synchronize passive yield (money-making-money) that doesn't emit standard EVM events.
* **🖥️ Reactive DApp Dashboard**: A React frontend featuring real-time TVL (Total Value Locked) charts, share price tracking, and smooth `Approve-then-Deposit` workflows using Wagmi and RainbowKit.

---

## 🏗️ Architecture & Tech Stack

### 1. Smart Contracts (Blockchain Layer)
- **Framework**: Foundry (Forge, Anvil, Cast)
- **Libraries**: OpenZeppelin V5, Aave V3 Core
- **Key Contracts**: `Vault.sol` (Core), `AaveStrategy.sol` (Yield Generator)

### 2. Indexer & API (Backend Layer)
- **Language**: Go 1.21+
- **Framework**: Gin (HTTP), GORM (ORM)
- **Blockchain SDK**: `go-ethereum` (Geth)
- **Database**: PostgreSQL

### 3. DApp (Frontend Layer)
- **Framework**: React 18, TypeScript, Vite
- **Web3 Tools**: Wagmi, Viem, RainbowKit
- **Charts**: Recharts

---

## 📂 Project Structure

- backend/             # Go Indexer & API Server
  - abi/               # Generated Go ABI bindings
  - config/            # Database and RPC configurations
  - database/          # PostgreSQL models and GORM setup
  - listener/          # WebSocket event listeners
  - reconciler/        # 5-sec polling yield sync bot
  - main.go            # Backend entry point
- contracts/           # Foundry Smart Contract Project
  - src/
    - Vault.sol        # ERC-4626 Vault
    - AaveStrategy.sol # Aave V3 Yield Router
  - test/              # Foundry Tests
  - script/            # Deployment scripts
- frontend/            # React DApp
  - src/
    - components/      # ActionPanel, TVLChart, etc.
    - hooks/           # Custom Wagmi hooks
    - App.tsx          # Dashboard layout

---

## 🚀 Quick Start

### Prerequisites
- Foundry installed
- Go 1.21+ installed
- Node.js 18+ & npm installed
- PostgreSQL running locally (Default port 5432)

### 1. Smart Contracts & Local Blockchain

Start a local Anvil chain by forking the Sepolia Testnet (required to simulate Aave V3 environment):

$ anvil --fork-url https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

In a new terminal, deploy the Vault and AaveStrategy:

$ cd contracts
$ forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

### 2. Backend Indexer (Go)

Configure your `config.yaml` or `.env` with the deployed contract addresses and database credentials.

$ cd backend
$ go mod tidy
$ go run main.go

*The backend API will be available at http://localhost:8080.*

### 3. Frontend DApp (React)

$ cd frontend
$ npm install
$ npm run dev

*The DApp will be available at http://localhost:5173.*

---

## 🔌 API Endpoints (Backend)

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET`  | `/api/tvl` | Returns the current Total Value Locked and Share Price. |
| `GET`  | `/api/history` | Returns historical TVL data for chart rendering. |
| `GET`  | `/api/events` | Returns recent deposit and withdraw activities. |

---

## 🔒 Security Implementations

* **Checks-Effects-Interactions (CEI)** pattern strictly followed to prevent reentrancy.
* **Pull Pattern**: `AaveStrategy` safely pulls assets from the `Vault` using `safeTransferFrom`.
* **Inflation Attack Protection**: Handled automatically via OpenZeppelin V5's virtual offset mechanism.
* **Upgrade Resistance**: Aave Pool addresses are fetched dynamically to prevent lockups during protocol upgrades.

---

## 🗺️ Roadmap / TODO

- [x] Local MVP Closure (Deposit/Withdraw Loop)
- [x] Yield Strategy Integration (Aave V3 Forking)
- [x] Backend Reconciler for Syncing Passive Yield
- [ ] **Security**: Implement `ReentrancyGuard` and `Pausable` for emergency brakes.
- [ ] **Deployment**: Public Sepolia Testnet Deployment.
- [ ] **Frontend**: User-specific Dashboard (My ROI) & APY calculation.
- [ ] **DevOps**: Dockerize the entire stack (Postgres + Redis + Go Backend).

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👨‍💻 Author

**GuangchaoYi**
* Full Stack Developer (Go / Java / Solidity)
* [https://github.com/yiguangchao]