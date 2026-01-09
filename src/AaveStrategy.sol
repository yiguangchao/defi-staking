// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

contract AaveStrategy is IStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset; // USDT
    IERC20 public immutable aToken; // aEthUSDT
    IAavePool public aavePool; // Aave Pool
    address public immutable provider; // Address provider

    constructor(address _asset, address _aToken, address _provider) {
        asset = IERC20(_asset);
        aToken = IERC20(_aToken);
        provider = _provider;

        // Get the latest Pool address during initialization
        _updatePool();
    }

    // --- Auxiliary function: dynamically update Pool address ---
    function _updatePool() internal {
        address poolAddress = IPoolAddressesProvider(provider).getPool();
        aavePool = IAavePool(poolAddress);
    }

    // --- IStrategy interface implementation ---

    function deposit(uint256 amount) external override {
        // Refresh Pool Address (Defensive Programming to Prevent Aave Upgrades)
        _updatePool();

        // Pull assets from Vault to Strategy
        asset.safeTransferFrom(msg.sender, address(this), amount);

        // Authorize Aave to deduct payment
        asset.forceApprove(address(aavePool), amount);

        // Deposit into Aave
        aavePool.supply(address(asset), amount, address(this), 0);
    }

    function withdraw(uint256 amount) external override {
        _updatePool();

        // Retrieve from Aave
        aavePool.withdraw(address(asset), amount, address(this));

        // Send back to Vault (msg. sender)
        asset.safeTransfer(msg.sender, amount);
    }

    function withdrawAll() external override {
        _updatePool();

        // Check the total balance of Aave
        uint256 balance = aToken.balanceOf(address(this));

        if (balance > 0) {
            // Type (uint256). max represents "taking all light" in Aave
            aavePool.withdraw(address(asset), type(uint256).max, address(this));

            // Transfer all retrieved USDT to Vault
            uint256 assetBalance = asset.balanceOf(address(this));
            asset.safeTransfer(msg.sender, assetBalance);
        }
    }

    function totalAssets() external view override returns (uint256) {
        // The total assets of the strategy=aToken balance held
        return aToken.balanceOf(address(this));
    }
}
