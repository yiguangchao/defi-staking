// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {AaveStrategy} from "../src/AaveStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployAaveVault is Script {
    // DAI Address
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

    // Aave V3 aEthDAI
    address constant A_TOKEN = 0x018008bfb33d285247A21d44E50697654f754e63;

    // Aave V3 Pool Addresses Provider
    address constant PROVIDER = 0x2f39d218133af9B3AF5147290F239068cA724888;

    // Binance Whale (DAI)
    address constant BINANCE_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

    // Anvil Default User
    address constant TEST_USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        uint256 deployerPrivateKey = 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6;

        vm.startBroadcast(deployerPrivateKey);

        // --- 2. Deploy Aave strategy ---
        AaveStrategy strategy = new AaveStrategy(DAI, A_TOKEN, PROVIDER);
        console.log("AaveStrategy deployed at:", address(strategy));

        // --- 3. Deploy the vault ---
        Vault vault = new Vault(IERC20(DAI), "Vault Aave DAI", "vDAI", address(strategy));
        console.log("Vault deployed at:", address(vault));

        vm.stopBroadcast();

        // --- 4. Borrowing money from a giant whale (simulated environment) ---
        vm.startPrank(BINANCE_WHALE);
        IERC20(DAI).transfer(TEST_USER, 10000 * 1e18);
        console.log("Stole 10,000 DAI from Whale to Test User");
        vm.stopPrank();
    }
}
