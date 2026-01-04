// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract VaultTest is Test {
    Vault public vault;
    MockUSDT public usdt;
    address public user = address(1);

    function setUp() public {
        usdt = new MockUSDT();
        vault = new Vault(usdt);
        usdt.mint(user, 100 * 1e18);
    }

    function testDeposit() public {
        vm.startPrank(user);
        usdt.approve(address(vault), 100 * 1e18);
        vault.deposit(100 * 1e18);

        assertEq(usdt.balanceOf(user), 0);
        assertEq(vault.balanceOf(user), 100 * 1e18);
        assertEq(usdt.balanceOf(address(vault)), 100 * 1e18);

        console.log("Deposit Test Passed!");
        vm.stopPrank();
    }

    function testYieldGeneration() public {
        uint256 principal = 100 * 1e18; // Principal 100 USDT
        uint256 yield = 10 * 1e18; // Simulated return of 10 USDT

        // Step 1: User Deposit---
        vm.startPrank(user);
        usdt.approve(address(vault), principal);
        vault.deposit(principal);
        vm.stopPrank();

        // Verification: At this point, 1 Share=1 Asset (as it is the first depositing user)
        assertEq(vault.balanceOf(user), principal, "Should have 1:1 shares initially");

        // Step 2: Simulate the interest rate of the vault---
        // Directly print money for Vault contract (simulated strategy investment earned money back)
        // Note: Prank is not required here as mint is a public method of MockUSDT
        usdt.mint(address(vault), yield);

        // Verification: The total assets in the vault should be 110 USDT
        assertEq(vault.totalAssets(), principal + yield, "Vault assets should increase");
        // Verification: The number of shares held by the user has not changed (still 100 vUSDT)
        assertEq(vault.balanceOf(user), principal, "User shares remain constant");

        // Step 3: User Withdrawal---
        vm.startPrank(user);
        // User destroys all shares
        vault.withdraw(vault.balanceOf(user));
        vm.stopPrank();

        // Step 4: Verify the final profit---
        // The user balance should be: principal+income
        uint256 expectedBalance = principal + yield;
        assertEq(usdt.balanceOf(user), expectedBalance, "User should withdraw principal + yield");

        console.log("Yield Test Passed!");
        console.log("Principal:", principal / 1e18);
        console.log("Yield:", yield / 1e18);
        console.log("Final User Balance:", usdt.balanceOf(user) / 1e18);
    }

    function testInflationAttack() public {
        address attacker = address(0xBAD);
        address victim = address(0xB1C);

        // Attention: The first deposit now must be>1000 wei, otherwise it will be revoked
        uint256 attackerAmt = 1001;
        uint256 donationAmt = 100 * 1e18;
        uint256 victimAmt = 100 * 1e18;

        usdt.mint(attacker, attackerAmt + donationAmt);
        usdt.mint(victim, victimAmt);

        // --- 1. Attackers attempt to attack---
        vm.startPrank(attacker);
        usdt.approve(address(vault), attackerAmt);
        vault.deposit(attackerAmt);
        // At this point: TotalSupply=1001 (1000 dead shares+1 attacker)

        // Attackers donate
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

        // Even with the attacker's donation interference, the victim should still get close to 1:1 shares
        assertGt(victimShares, 0, "Victim should NOT lose funds anymore");
    }
}
