// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

contract Vault is ERC20 {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IStrategy public strategy;

    constructor(IERC20 _asset, IStrategy _strategy) ERC20("Vault USDT", "vUSDT") {
        asset = _asset;
        strategy = _strategy;
    }

    function deposit(uint256 assets) public {
        require(assets > 0, "Deposit > 0");

        uint256 shares;
        if (totalSupply() == 0) {
            require(assets > 1000, "First deposit > 1000");
            shares = assets - 1000;
            _mint(address(0xdead), 1000);
        } else {
            shares = (assets * totalSupply()) / totalAssets();
        }

        // 1. Transfer to Vault
        asset.safeTransferFrom(msg.sender, address(this), assets);

        // 2. Transfer to Strategy
        asset.forceApprove(address(strategy), assets);
        strategy.deposit(assets);

        _mint(msg.sender, shares);
    }

    function withdraw(uint256 shares) public {
        require(shares > 0, "Shares > 0");
        require(balanceOf(msg.sender) >= shares, "Insufficient balance");

        uint256 payoutAmount = (shares * totalAssets()) / totalSupply();
        _burn(msg.sender, shares);

        // Check the vault balance, if it's not enough, ask Strategy for assistance
        uint256 float = asset.balanceOf(address(this));
        if (float < payoutAmount) {
            uint256 shortage = payoutAmount - float;
            strategy.withdraw(shortage);
        }

        asset.safeTransfer(msg.sender, payoutAmount);
    }

    // Assets=Vault balance+Strategy balance
    function totalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + strategy.totalAssets();
    }
}
