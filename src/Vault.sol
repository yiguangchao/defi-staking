// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Vault the contract itself is also an ERC20 token (representing shares)
contract Vault is ERC20 {
    // 1. state variable
    IERC20 public immutable asset; // Underlying assets (such as USDT)

    // 2. constructor
    // _asset: what token we want to deposit (USDT address)
    // "Vault USDT", "vUSDT": the name of the token that users receive
    constructor(IERC20 _asset) ERC20("Vault USDT", "vUSDT") {
        asset = _asset;
    }

    // ==========================================
    // 3. Deposit Logic
    // User deposits assets (USDT) ->receives shares (vUSDT)
    // ==========================================
    function deposit(uint256 assets) public {
        require(assets > 0, "Deposit amount must be greater than 0");

        // A. Calculate how many shares can be exchanged (Shares)
        uint256 shares;
        if (totalSupply() == 0) {
            // If it is the first person to deposit, 1 Asset=1 Share (1:1)
            shares = assets;
        } else {
            // If someone has already deposited, calculate based on the current exchange rate
            // Formula: shares=(deposit amount * total shares)/total assets of the vault
            // Example: Save 100, Total 1000, Total 1100->100 * 1000/1100=90 shares
            shares = (assets * totalSupply()) / totalAssets();
        }

        // B. First, transfer the user's money in (Checks-Effects Interactions mode: 
        // change the status first and then transfer, this is slightly special because mint is at the end)
        // Attention: Users must first approve this contract!
        // The return value of transferFrom needs to be checked (SafeERC20 is omitted here for code simplicity,
        // and must be used in production environments)
        bool success = asset.transferFrom(msg.sender, address(this), assets);
        require(success, "Transfer failed");

        //C. Casting vouchers for users
        _mint(msg.sender, shares);

        // D. (Optional) Throw an event for Go Indexer to listen
        // emit Deposit(msg.sender, assets, shares);
    }

    // ==========================================
    // 4. Withdraw Logic
    // User burns shares (vUSDT) -> gets back assets (USDT)
    // ==========================================
    function withdraw(uint256 shares) public {
        require(shares > 0, "Shares must be greater than 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient balance");

        // A. Calculate how much assets can be withdrawn
        // Formula: assets = (burned shares * vault total assets) / total shares
        // Example: burn 10, total assets 1100, total shares 100 -> 10 * 1100 / 100 = 110 assets
        uint256 payoutAmount = (shares * totalAssets()) / totalSupply();

        // B. Destroy the user's vouchers
        _burn(msg.sender, shares);

        // C. Transfer the money to the user
        bool success = asset.transfer(msg.sender, payoutAmount);
        require(success, "Transfer failed");

        // D. (Optional) Throw an event
        // emit Withdraw(msg.sender, payoutAmount, shares);
    }
    
    // How many are currently in the vault USDT
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}