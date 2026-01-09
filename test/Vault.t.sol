// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockStrategy} from "../src/MockStrategy.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

// --- 1. Define a simple test token ---
contract MockToken is ERC20 {
    constructor() ERC20("Mock Token", "MCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

// --- 2. Vault test script ---
contract VaultTest is Test {
    Vault public vault;
    MockStrategy public strategy;
    MockToken public token;

    address user = address(0x1);

    function setUp() public {
        // 1. Deploy test tokens(Asset)
        token = new MockToken();

        // 2. Deploy Mock Strategy (passing Asset)
        strategy = new MockStrategy(address(token));

        // 3. Deploy Vault
        vault = new Vault(token, "Test Vault", "tvUSDT", address(strategy));

        // 4. Send money to the testing user and authorize them
        token.mint(user, 1000 * 1e18);

        vm.startPrank(user);
        token.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    function testDeposit() public {
        vm.startPrank(user);
        uint256 amount = 100 * 1e18;

        // Savings: User ->Vault ->Strategy
        uint256 shares = vault.deposit(amount, user);

        // Verification:
        // 1. The user received shares (vToken)
        assertEq(shares, amount, "Shares should be 1:1 initially");
        assertEq(vault.balanceOf(user), amount, "User balance match");

        // 2. Is the money really in Strategy?
        // Note: MockStrategy only holds tokens
        assertEq(token.balanceOf(address(strategy)), amount, "Strategy should hold the funds");

        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(user);
        uint256 amount = 50 * 1e18;

        // First deposit
        vault.deposit(amount, user);

        // Then withdraw
        // Parameters: how much assets to withdraw, who to give the assets to, whose shares to burn
        vault.withdraw(amount, user, user);

        // Verification:
        // 1. Shares burned
        assertEq(vault.balanceOf(user), 0, "Shares should be burned");

        // 2. The money returned to the user's pocket
        assertEq(token.balanceOf(user), 1000 * 1e18, "User should get funds back");

        // 3. Strategy should be empty
        assertEq(token.balanceOf(address(strategy)), 0, "Strategy should be empty");

        vm.stopPrank();
    }
}
