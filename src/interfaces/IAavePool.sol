// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAavePool {
    // Deposit: Deposit the asset and generate an aToken on the onBehalfOf address
    function supply(
        address asset, 
        uint256 amount, 
        address onBehalfOf, 
        uint16 referralCode
    ) external;

    // Withdrawal: Destroy aToken and retrieve asset
    function withdraw(
        address asset, 
        uint256 amount, 
        address to
    ) external returns (uint256);
}