// frontend/src/constants.ts

export const VAULT_ADDRESS = "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0";

export const VAULT_ABI = [
  // deposit
  "function deposit(uint256 assets, address receiver)",
  
  // withdraw
  "function withdraw(uint256 assets, address receiver, address owner)"
] as const;