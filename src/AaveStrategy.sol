// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategy} from "./interfaces/IStrategy.sol";
import {IAavePool} from "./interfaces/IAavePool.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

contract AaveStrategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset; // USDT
    IERC20 public immutable aToken; // aEthUSDT
    IAavePool public immutable aavePool; // Aave

    constructor(IERC20 _asset, IERC20 _aToken, IAavePool _aavePool) {
        asset = _asset;
        aToken = _aToken;
        aavePool = _aavePool;
    }

    function deposit(uint256 amount) external {
        // 1. Pull USDT from Vault (provided that Vault has approved the Strategy)
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // 2. Authorize Aave Pool to use our USDT
        asset.forceApprove(address(aavePool), amount);

        // 3. Call Aave Supply
        aavePool.supply(address(asset), amount, address(this), 0);
    }

    function withdraw(uint256 amount) external {
        // Retrieve USDT from Aave
        aavePool.withdraw(address(asset), amount, address(this));

        // Return the retrieved USDT to the Vault (msg. sender)
        asset.safeTransfer(msg.sender, amount);
    }

    function harvest() external {}

    // Core: Our total assets = aToken balance
    // Since aToken is also an ERC20, and its balance increases over time (1 aUSDT = 1 USDT)
    function totalAssets() external view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}
