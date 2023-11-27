// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import "forge-std/Test.sol"; // Import Forge's standard testing library
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "../LiquidityPool.sol";

// Mock ERC20 Token for testing
contract MockERC20 is ERC20 {
    constructor() ERC20("MockToken", "MKT") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract LiquidityPoolTest is DSTest {
    LiquidityPool private liquidityPool;
    MockERC20 private liquidityToken;
    address private owner;
    address private user;

    function setUp() public {
        owner = address(this); // In tests, the deploying contract can act as the owner
        user = address(0x123); // Example user address
        liquidityToken = new MockERC20(); // Deploy a mock ERC20 token
        liquidityPool = new LiquidityPool();
        liquidityPool.initialize(address(liquidityToken));

        // Mint tokens to the user and approve the pool
        liquidityToken.mint(user, 1000 ether);
        liquidityToken.approve(address(liquidityPool), 1000 ether);
    }

    function testInitializeCanBeCalledOnce() public {
    // This should pass as initialize has already been called in setUp
    try liquidityPool.initialize(address(liquidityToken)) {
        assertTrue(false, "initialize was called more than once");
    } catch Error(string memory reason) {
        // This is expected, so we assert that the revert reason is correct
        assertEq(reason, "Initializable: contract is already initialized");
    } catch {
        // Catch all other kinds of reverts
        assertTrue(true);
    }
}

   



    // Additional test cases for other functionalities and vulnerabilities...
}