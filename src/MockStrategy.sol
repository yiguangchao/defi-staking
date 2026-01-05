// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategy} from "./interfaces/IStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockStrategy is IStrategy {
    using SafeERC20 for IERC20;
    IERC20 public immutable asset;

    constructor(IERC20 _asset) {
        asset = _asset;
    }

    function deposit(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        asset.safeTransfer(msg.sender, amount);
    }

    function harvest() external {}

    function totalAssets() external view returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
