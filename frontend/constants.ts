// frontend/src/constants.ts

export const VAULT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

export const VAULT_ABI = [
  // deposit
  "function deposit(uint256 assets, address receiver)",
  
  // withdraw
  "function withdraw(uint256 assets, address receiver, address owner)"
] as const;

export const ERC20_ABI = [
  // Query authorization limit: allowance (owner, payer)
  "function allowance(address owner, address spender) view returns (uint256)",
  // Perform authorization: approve(spender, amount)
  "function approve(address spender, uint256 amount) returns (bool)",
  // Query balance (optional, for optimization)
  "function balanceOf(address account) view returns (uint256)",
  // Query what token this Vault uses (e.g. USDT or DAI?)
  "function asset() view returns (address)",
  //Ordinary transfer function (used to simulate sending money)
  "function transfer(address to, uint256 amount) returns (bool)"
] as const;