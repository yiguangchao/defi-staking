// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStrategy {
    // Deposit: Invest assets (USDT) into third-party agreements (Aave)
    function deposit(uint256 amount) external;

    // Withdrawal: Retrieve assets from third-party protocols to Vault
    function withdraw(uint256 amount) external;

    // Audit: How much money is currently in the strategy (principal+interest)
    function totalAssets() external view returns (uint256);

    // Monetization: Retrieve all assets, usually used for emergency evacuation
    function withdrawAll() external;
}
