// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "openzeppelin-contracts/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {AccessControl} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {IStrategy} from "./interfaces/IStrategy.sol";

contract Vault is ERC4626, AccessControl {
    using SafeERC20 for IERC20;

    // Simulation: Total assets are the balance in the current contract
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // The currently used strategy
    IStrategy public strategy;

    constructor(IERC20 _asset, string memory _name, string memory _symbol, address _strategy)
        ERC4626(_asset)
        ERC20(_name, _symbol)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        strategy = IStrategy(_strategy);
    }

    // When users deposit money into Vault, Vault automatically transfers the money to Strategy for investment
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        // 1. Parent class logic: First transfer money from the user to the vault and mint shares
        super._deposit(caller, receiver, assets, shares);

        // 2. Investment logic: Vault transfers the just received money to Strategy
        IERC20(asset()).forceApprove(address(strategy), assets);
        strategy.deposit(assets);
    }

    // When the user withdraws money, Vault commands Strategy to redeem the money back
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        // 1. Withdrawal logic: Let Strategy spit out the money and return it to the vault first
        strategy.withdraw(assets);

        // 2. Parent class logic: Vault destroys shares, returns money to user
        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // --- Accounting logic ---
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this)) + strategy.totalAssets();
    }
}
