// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
}

interface IAavePool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
}

contract DynamicStrategy {
    using SafeERC20 for IERC20;

    IERC20 public immutable asset;
    IERC20 public immutable aToken;
    IAavePool public immutable aavePool;

    constructor(address _asset, address _aToken, address _pool) {
        asset = IERC20(_asset);
        aToken = IERC20(_aToken);
        aavePool = IAavePool(_pool);
    }

    function deposit(uint256 amount) external {
        asset.safeTransferFrom(msg.sender, address(this), amount);
        asset.forceApprove(address(aavePool), amount);
        aavePool.supply(address(asset), amount, address(this), 0);
    }

    function withdraw(uint256 amount) external {
        aavePool.withdraw(address(asset), amount, address(this));
        asset.safeTransfer(msg.sender, amount);
    }

    function totalAssets() external view returns (uint256) {
        return aToken.balanceOf(address(this));
    }
}

contract AaveRegistryTest is Test {
    using SafeERC20 for IERC20;

    address constant PROVIDER_ADDR = 0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;

    address constant USDT_ADDR = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant A_USDT_ADDR = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a;

    string RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/e8WW1ln1MXAyRT8rWjPpg";

    DynamicStrategy strategy;
    IERC20 usdt = IERC20(USDT_ADDR);
    IERC20 aUsdt = IERC20(A_USDT_ADDR);

    function setUp() public {
        vm.createSelectFork(RPC_URL, 19800000);

        address realPoolAddress = IPoolAddressesProvider(PROVIDER_ADDR).getPool();
        console.log("Real Pool Address:", realPoolAddress);

        strategy = new DynamicStrategy(USDT_ADDR, A_USDT_ADDR, realPoolAddress);

        deal(USDT_ADDR, address(this), 5000 * 1e6);
    }

    function testYieldGeneration() public {
        uint256 amount = 1000 * 1e6;
        usdt.forceApprove(address(strategy), amount);

        console.log(">> Depositing 1000 USDT...");
        strategy.deposit(amount);

        uint256 balanceBefore = strategy.totalAssets();
        console.log("Balance Before:", balanceBefore);

        assertApproxEqAbs(balanceBefore, amount, 10, "Initial balance match");

        console.log(">> Warping time 365 days...");
        vm.warp(block.timestamp + 365 days);
        vm.roll(block.number + 2600000);

        uint256 balanceAfter = strategy.totalAssets();
        console.log("Balance After :", balanceAfter);

        assertGt(balanceAfter, balanceBefore, "Yield should be generated!");

        uint256 profit = balanceAfter - balanceBefore;
        console.log("Profit generated (in 1 year):", profit);
        console.log("APY (approx):", profit * 10000 / balanceBefore);
    }
}
