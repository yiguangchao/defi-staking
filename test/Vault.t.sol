// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {MockStrategy} from "../src/MockStrategy.sol";

contract VaultTest is Test {
    Vault public vault;
    MockUSDT public usdt;
    MockStrategy public strategy;
    address public user = address(1);

    function setUp() public {
        usdt = new MockUSDT();
        
        // 1. Deploy the strategy first
        strategy = new MockStrategy(usdt);
        
        // 2. Injection strategy when deploying Vault (dependency injection)
        vault = new Vault(usdt, strategy);
        
        usdt.mint(user, 100 * 1e18); 
    }

    function testDeposit() public {
        vm.startPrank(user);
        usdt.approve(address(vault), 100 * 1e18);
        vault.deposit(100 * 1e18);

        assertEq(usdt.balanceOf(user), 0);
        
        // Verify dead stock logic (Deposit -1000)
        assertEq(vault.balanceOf(user), 100 * 1e18 - 1000, "Should mint shares minus dead shares");
        
        // Verify the destination of funds:
        // The money should not be in the vault, but should be transferred to the strategy!
        assertEq(usdt.balanceOf(address(vault)), 0, "Vault should hold 0 float");
        assertEq(usdt.balanceOf(address(strategy)), 100 * 1e18, "Strategy should hold all funds");

        console.log("Deposit Test Passed!");
        vm.stopPrank();
    }

    function testInflationAttack() public {
        address attacker = address(0xBAD);
        address victim = address(0xB1C);
        
        uint256 attackerAmt = 1001; 
        uint256 donationAmt = 100 * 1e18;
        uint256 victimAmt = 100 * 1e18;

        usdt.mint(attacker, attackerAmt + donationAmt);
        usdt.mint(victim, victimAmt);

        // --- 1. Attackers attempt to attack---
        vm.startPrank(attacker);
        usdt.approve(address(vault), attackerAmt);
        vault.deposit(attackerAmt); 
        
        usdt.transfer(address(vault), donationAmt);
        vm.stopPrank();

        // --- 2. Victims' deposits---
        vm.startPrank(victim);
        usdt.approve(address(vault), victimAmt);
        vault.deposit(victimAmt);
        vm.stopPrank();

        // --- 3. Verification results---
        uint256 victimShares = vault.balanceOf(victim);
        console.log("Victim Shares:", victimShares);

        assertGt(victimShares, 0, "Victim should NOT lose funds anymore");
    }

    function testYieldGeneration() public {
        uint256 principal = 100 * 1e18; 
        uint256 yield = 10 * 1e18;      

        // ---Step 1: User Deposit---
        vm.startPrank(user);
        usdt.approve(address(vault), principal);
        vault.deposit(principal);
        vm.stopPrank();

        assertEq(vault.balanceOf(user), principal - 1000, "Should have principal minus dead shares");

        // ---Step 2: Simulate the interest rate of the vault---
        usdt.mint(address(strategy), yield);

        // Verification: Vault's total Assets() recursively calls strategy. total Assets()
        assertEq(vault.totalAssets(), principal + yield, "Vault assets should increase");
        assertEq(vault.balanceOf(user), principal - 1000, "User shares remain constant");

        // ---Step 3: User Withdraw---
        vm.startPrank(user);
        vault.withdraw(vault.balanceOf(user)); 
        vm.stopPrank();

        // ---Step 4: Verify final profit ---
        assertGt(usdt.balanceOf(user), principal, "User should make a profit");
        
        console.log("Yield Test Passed!");
    }
}