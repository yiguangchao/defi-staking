// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Vault the contract itself is also an ERC20 token (representing shares)
contract Vault is ERC20 {
    // 1. state variable
    IERC20 public immutable ASSET; // Underlying assets (such as USDT)

    // 2. constructor
    // _asset: what token we want to deposit (USDT address)
    // "Vault USDT", "vUSDT": the name of the token that users receive
    constructor(IERC20 _asset) ERC20("Vault USDT", "vUSDT") {
        ASSET = _asset;
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
            // ---  🛡️  Defense core code---
            // During the first coinage, a forced sacrifice of 1000 wei of shares was given to 0 addresses (dead shares)
            // This ensures that the total supply is always at least 1000, preventing manipulation
            // caused by a denominator that is too small
            require(assets > 1000, "First deposit must be > 1000 wei");

            // After deducting 1000, the remaining amount is given to the user
            shares = assets - 1000;
            _mint(address(0xdead), 1000);
        } else {
            // Subsequent deposits will be calculated as usual
            shares = (assets * totalSupply()) / totalAssets();
        }

        bool success = ASSET.transferFrom(msg.sender, address(this), assets);
        require(success, "Transfer failed");

        _mint(msg.sender, shares);
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
        bool success = ASSET.transfer(msg.sender, payoutAmount);
        require(success, "Transfer failed");

        // D. (Optional) Throw an event
        // emit Withdraw(msg.sender, payoutAmount, shares);
    }

    // How many are currently in the vault USDT
    function totalAssets() public view returns (uint256) {
        return ASSET.balanceOf(address(this));
    }
}
