// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "ds-test/test.sol";
import "forge-std/Test.sol"; // Import Forge's standard testing library
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../Token.sol"; // Import the Token contract

contract TokenTest is Test { // Extend from 'Test' instead of 'DSTest'
  Token token;
  address owner;
  address user1;
    function setUp() public {
        owner = address(this);
        user1 = address(1);
        token = new Token("TestToken", "TT", 100000 ether);
    }
function testBurnFunctionConstraints() public {
    uint256 initialBalance = token.balanceOf(owner);
    uint256 burnAmount = initialBalance / 2;
    uint256 expectedSupplyAfterBurn = token.totalSupply() - burnAmount;

    token.burn(burnAmount);

    assertEq(token.balanceOf(owner), initialBalance - burnAmount, "Incorrect balance after burn");
    assertEq(token.totalSupply(), expectedSupplyAfterBurn, "Total supply not reduced correctly after burn");
}

function testFailBurnMoreThanBalance() public {
    uint256 burnAmount = token.balanceOf(owner) + 1 ether;
    token.burn(burnAmount); // This should fail
}

function testFailUnauthorizedBurn() public {
    uint256 burnAmount = 10 ether;
    Token(user1).burn(burnAmount); // This should fail as user1 does not own tokens initially
}
function testCentralizedDistributionAndMaxSupply() public {
    uint256 initialSupply = token.totalSupply();
    uint256 maxSupply = token.maxSupply();
    address deployer = address(this); // Assuming the test contract is the deployer

    // Check that total supply equals initial supply minted to deployer
    assertEq(token.balanceOf(deployer), initialSupply, "Deployer should hold all initial tokens");

    // Verify that maxSupply has no bearing on the total supply
    assertEq(maxSupply, 1000000 ether, "Max supply should be set to 1000000 ether");
    
    // Assert the total supply remains unchanged, indicating no further minting
    assertEq(token.totalSupply(), initialSupply, "Total supply should not change, indicating no further minting");
}

}