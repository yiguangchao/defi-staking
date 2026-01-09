// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "../../src/interfaces/IStrategy.sol";

contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;

    constructor(address _asset) {
        asset = IERC20(_asset);
    }

    function deposit(uint256 amount) external override {
        // Mock: Just transferring money from the vault and storing it
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external override {
        // Mock: Transfer money back to Vault
        asset.safeTransfer(msg.sender, amount);
    }

    // Emergency withdrawal
    function withdrawAll() external override {
        uint256 balance = asset.balanceOf(address(this));
        if (balance > 0) {
            asset.safeTransfer(msg.sender, balance);
        }
    }

    function totalAssets() external view override returns (uint256) {
        // Mock: Our total assets are the balance in the current contract
        return asset.balanceOf(address(this));
    }
}
