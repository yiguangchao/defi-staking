// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Vault} from "../src/Vault.sol";
import {AaveStrategy} from "../src/AaveStrategy.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract DeployAaveVault is Script {
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant A_TOKEN = 0x23878914EFE38d27C4D67Ab83ed1b93A74D404; // Aave V3 aEthUSDT
    address constant PROVIDER = 0x2f39d218133AF9B3af5147290f239068CA724888; // Aave V3 PoolAddressesProvider
    address constant BINANCE_WHALE = 0x47ac0Fb4F2D84898e4D9E7b4DaB3C24507a6D503;

    address constant TEST_USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    function run() external {
        // Obtain the private key of the deployer
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);

        // --- 2. Deploy Aave strategy---
        AaveStrategy strategy = new AaveStrategy(USDT, A_TOKEN, PROVIDER);
        console.log("AaveStrategy deployed at:", address(strategy));

        // --- 3. Deploy the vault---
        Vault vault = new Vault(IERC20(USDT), "Vault Aave USDT", "vaUSDT", address(strategy));
        console.log("Vault deployed at:", address(vault));

        vm.stopBroadcast();
        
        // --- 3. Deploy Vault - Simulate We Want to Become Binance Whale
        vm.startPrank(BINANCE_WHALE); 
        
        // Crazy transfer 10000 USDT to test user
        IERC20(USDT).transfer(TEST_USER, 10000 * 1e6);
        console.log("Stole 10,000 USDT from Whale to Test User");
        
        vm.stopPrank();
    }
}