// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {AaveStrategy} from "../src/AaveStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IAavePool} from "../src/interfaces/IAavePool.sol";

contract AaveStrategyTest is Test {
    address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant AAVE_POOL = 0x87870BCA3F3f637F37D8978f6213841C467a563F;

    address constant A_USDT = 0x23878914Efe38d27C4d67ab83eD1F93a74398C22;

    address constant WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    Vault vault;
    AaveStrategy strategy;
    IERC20 usdt = IERC20(USDT_ADDR);
    IERC20 aUsdt = IERC20(A_USDT);

    // Please switch to your own Alchemy/Infura URL
    string RPC_URL = "https://eth.llamarpc.com";

    function setUp() public {
        // 1. Create mainnet fork
        vm.createSelectFork(RPC_URL);

        // 2. Deploy contract
        strategy = new AaveStrategy(usdt, aUsdt, IAavePool(AAVE_POOL));
        vault = new Vault(usdt, strategy);

        // 3. Simulated Whale Transfer (USDT accuracy is 6)
        vm.startPrank(WHALE);
        usdt.transfer(address(this), 2000 * 1e6);
        vm.stopPrank();
    }

    function testIntegration() public {
        uint256 amount = 1000 * 1e6; // 1000 USDT (6 decimals)

        // 1. Approve and deposit
        usdt.approve(address(vault), amount);
        vault.deposit(amount);

        // 2. Verify the destination of funds
        assertEq(usdt.balanceOf(address(vault)), 0, "Vault should not hold USDT");
        assertEq(usdt.balanceOf(address(strategy)), 0, "Strategy should have supplied USDT to Aave");

        // Strategy should hold aUSDT (with minimal margin of error, use approval)
        assertApproxEqAbs(aUsdt.balanceOf(address(strategy)), amount, 1e6, "Strategy should hold aUSDT");

        console.log("Deposit Success! Strategy holds aUSDT:", aUsdt.balanceOf(address(strategy)));

        // 3. Withdrawal Test
        vault.withdraw(vault.balanceOf(address(this)));

        // Verify the retrieved amount (allowing for a slight loss of dead shares and accuracy)
        assertGt(usdt.balanceOf(address(this)), amount - 2000, "Should withdraw principal");
    }
}
