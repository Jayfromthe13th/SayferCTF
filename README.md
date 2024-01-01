# Audit Review - SauferCTF👇🏾




# `Token.sol`

## C-01: Unauthorized Token Burning in Burn Function
**Location:** `Token.sol#Ln3`

### Proof of Concept (PoC):
```solidity
function testBurnLogicIssue() public {
    // Burn nearly all tokens
    uint256 burnAmount = token.totalSupply() - 1 ether;
    token.burn(burnAmount);

    // Try burning a small amount after a large burn
    // This test should fail if the logic issue exists
    token.burn(1 ether);
}
 ```


### Description:
The burn function in the Token contract allows any user, regardless of their token balance, to burn tokens. This behavior is contrary to the standard ERC20 token implementation, where users can only burn tokens they own. The vulnerability arises due to the lack of a balance check before executing the burn operation. This issue could lead to situations where users are able to burn tokens they do not own, effectively reducing the total supply of the token in an unauthorized manner.

### Recommendation:
Implement a balance check in the burn function to ensure that the caller cannot burn more tokens than they own. This can be achieved by comparing the caller's token balance with the amount they wish to burn, and reverting the transaction if the balance is insufficient.

### Resolution:
A potential resolution would involve modifying the burn function to include a balance check. For instance:
```solidity
function burn(uint256 amount) public nonReentrant {
require(balanceOf(msg.sender) >= amount, "Insufficient balance to burn");
// existing burn logic
}
```

This change ensures that a user cannot burn tokens beyond their current balance, aligning the contract's behavior with standard ERC20 practices and preventing unauthorized supply manipulation.

# C-02: Logic Issue in Burn Function Leading to Supply Manipulation
**Location:**  `Location: Token.sol#Ln3`

### PoC:
```solidity
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
```
### Description:
The burn function in the Token contract exhibits a logic flaw where it checks totalSupply().sub(totalBurned) >= amount before proceeding with the burn. This check is intended to prevent burning more than the available supply. However, it incorrectly restricts valid burn operations after a significant amount of tokens has been burned, potentially leading to a situation where users with a sufficient balance are unable to burn their tokens. This issue arises because the check compares the requested burn amount with the reduced total supply, rather than the caller's token balance.

### Recommendation:
The recommended solution is to remove the flawed supply check and rely solely on the internal balance check performed by the \_burn function. The \_burn function, as part of the ERC20 standard implementation, already ensures that a user cannot burn more tokens than they hold. The additional check is unnecessary and can lead to unintended restrictions.

### Resolution:
Modify the burn function by removing the problematic supply check. The updated function should look like:
```solidity
function burn(uint256 amount) public nonReentrant {
    require(amount > 0, "Burn amount must be greater than zero");
    \_burn(msg.sender, amount);
    totalBurned = totalBurned.add(amount);
    emit Burned(msg.sender, amount);
    }
```
This change ensures that the burn operation is only restricted by the user's token balance, aligning with standard ERC20 behavior and eliminating the unintended supply manipulation issue.

## C-03: Centralized Token Distribution and Unused Max Supply

**Location:** `Token.sol#Ln22-39 & 12`
```solidity
Proof of Concept (PoC):
function testCentralizedDistributionAndMaxSupply() public {
    uint256 initialSupply = token.totalSupply();
    uint256 maxSupply = token.maxSupply();
    address deployer = address(this); // Assuming the test contract is the deployer

    // Check that total supply equals initial supply minted to deployer
    assertEq(token.balanceOf(deployer), initialSupply, "Deployer should hold all initial tokens");

    // Verify that maxSupply has no bearing on the total supply
    assertEq(maxSupply, 1000000 ether, "Max supply should be set to 1000000 ether");

    // Assert the total supply remains unchanged, indicating no further minting
    assertEq(token.totalSupply(), initialSupply, "Total supply should not change, indicating no further              minting");

    }
```
### Description:
The contract initializes a token supply at deployment, assigning all tokens to the deployer, with no functionality to mint additional tokens post-deployment. This creates a highly centralized token distribution. Additionally, the maxSupply constant is defined but not utilized in any minting logic, making it redundant. This centralized control, combined with the ability to burn tokens, raises significant concerns regarding potential market manipulation, such as pump and dump schemes. The deployer, holding all initial tokens, can manipulate the market by selectively burning tokens or making large sales, impacting the token's price due to the fixed supply.

### Recommendation:
To mitigate these risks, consider implementing a decentralized token distribution mechanism and ensuring the maxSupply constant plays a functional role in governing the token supply. Introduce features allowing for additional token minting, controlled through a decentralized governance process or preset rules that align with the project's objectives.

### Resolution:
Revising the contract to include a dynamic minting function and utilizing the maxSupply constant as an enforceable cap would address these issues. Implementing a decentralized governance model for key decisions, like minting new tokens, can also help mitigate centralization risks.

# H-01 Exploitable Fee Mechanism in Transfer Function

**Location:** `Token.sol#Ln51`

### PoC:
Step-by-Step Exploit Procedure:

1)Owner Sets High Fees: The contract owner sets both the burnFee and the transferFee to their maximum permissible values (5% each).

2)Initiate a Transfer: A user (or the owner themselves) initiates a transfer of tokens to another address. This transfer could be of any amount, but the impact is more pronounced on smaller amounts.

3)Automatic Fee Deduction: Upon execution of the transfer, the contract automatically deducts a total of 10% from the transferred amount (5% burn fee + 5% transfer fee).

4)Token Burn and Supply Reduction: The 5% burn fee is permanently removed from the total supply of tokens, leading to a reduction in the overall supply.

5)Reduced Transfer Amount: The recipient receives only 90% of the sent amount due to the high fees, significantly less than expected.

6)Potential Repeat Exploitation: The owner can repeatedly adjust the fees and exploit users by either suddenly increasing fees before large transfers are known to occur or by consistently keeping fees high.

### Description:
The transfer function in the contract is susceptible to exploitation due to the owner's ability to set high burn and transfer fees. By setting each fee to the maximum of 5%, the owner can effectively reduce any transfer amount by 10%. This mechanism disproportionately affects smaller transactions and can be manipulated to either benefit the owner directly (if they are the recipient of the transactions) or to reduce the token's circulating supply rapidly through the burn fee. Users conducting transactions during these high-fee periods may incur significant and unexpected losses, leading to a loss of trust and value in the token.

### Recommendation:
Implement a hard cap on the combined total of the burn and transfer fees to prevent excessive deductions. Introduce a delay or governance process for changing fee percentages, ensuring transparency and predictability for token holders.

### Resolution:
To resolve this issue, the contract should be updated to include a maximum limit for the combined fees (e.g., no more than 5% in total) and a time-locked or governance-based mechanism for fee changes. This would prevent abrupt changes in fees and ensure that any adjustments are made transparently and with consideration of the token holders' interests. Additionally, providing a clear use case or distribution plan for collected transfer fees could enhance the token's ecosystem value.

# `Governance.sol`

## C-01: Double Voting Vulnerability

**Location:** `Governance.sol#Ln101`

### PoC:
```solidity
function testDoubleVoting() public {

    governance.vote(proposalId);
    uint256 firstVoteBalance = governance.balanceOf(address(this));
    governance.vote(proposalId);
    uint256 secondVoteBalance = governance.balanceOf(address(this));
    assertLt(secondVoteBalance, firstVoteBalance); // Should fail, indicating double voting

}
```
### Description:
The vote function does not check if hasVoted[msg.sender] was already true, allowing a user to call vote multiple times, each time decreasing their balance by 1 token.

### Recommendation:
Implement a check in the vote function to ensure that a user can only vote once per proposal.

### Resolution:
Adding a condition to verify if a user has already voted before allowing them to vote again would prevent this issue.

# H-01 Exploitable Vote Revoke Mechanism

**Location:**
``` solidity 
function revokeVote(uint256 proposalId) public nonReentrant

    onlyExistingProposal(proposalId) {
        ...
    balanceOf[msg.sender] = balanceOf[msg.sender].add(1);

}
```
### PoC:
```solidity 
function testVoteRevokeExploit() public {

    governance.vote(proposalId);
    governance.revokeVote(proposalId);
    governance.vote(proposalId);
    uint256 finalBalance = governance.balanceOf(address(this));
    assertEq(finalBalance, initialBalance - 1); // Should fail if revoke allows for double voting

    }
```
### Description:
The revokeVote function allows users to revoke their vote and regain a token, enabling them to vote again. This leads to the possibility of double voting.

### Recommendation:
Revoking a vote should either be disallowed or managed in a way that prevents further voting on the same proposal.

### Resolution:
Implement a mechanism to track votes per proposal per user, ensuring that a vote revoke does not allow re-voting on the same proposal.

# H-02 Inadequate Proposal Execution Validation

**Location:**
```solidity
function executeproposal(uint256 proposalId) public nonReentrant

    onlyExistingProposal(proposalId) {
        ...
    if (balanceOf[msg.sender] >= quorumVotes) {
    ...

    }
    }
```
### Proof of Concept (PoC):
```solidity 
function testInvalidProposalExecution() public {

    uint256 proposalId = createValidProposal();
    increaseBalanceToQuorum(msg.sender); // Assume this function increases the balance to meet quorum
    governance.executeproposal(proposalId);
    assertTrue(governance.proposals(proposalId).executed); // Should fail, proposal execution should not depend         solely on executor's balance

    }
```
### Description:
The executeproposal function determines proposal execution eligibility based on the executor’s token balance, not on actual votes cast, which is not a typical or secure way to handle governance decisions.

### Recommendation:
Change the execution logic to depend on the total votes cast for the proposal, rather than the executor's token balance.

### Resolution:
Implement a voting tally mechanism that accurately reflects the community's decision on a proposal.

# M-01 Ineffective Proposal Deposit Mechanism

**Location:**
```soildity 
function createProposal(uint256 amount) public nonReentrant {

    ...
    balanceOf[msg.sender] = balanceOf[msg.sender].sub(proposalDeposit);
    ...

}
```
### Proof of Concept (PoC):
```solidity 
function testProposalDepositHandling() public {

    uint256 initialBalance = governance.balanceOf(address(this));
    governance.createProposal(validAmount);
    uint256 postCreateBalance = governance.balanceOf(address(this));
    assertEq(postCreateBalance, initialBalance - proposalDeposit); // Should fail if deposit is not properly         handled

}
```
### Description:
The createProposal function decreases the proposer's balance to represent a deposit, but does not actually transfer any tokens to the contract or lock them in any way. This could be problematic if the deposit is intended to have a real economic cost.

### Recommendation:
Consider implementing a mechanism that either locks the deposit tokens in the contract or transfers them to a designated address to ensure there is a tangible cost associated with proposal creation.

### Resolution:
Modify the createProposal function to include a token transfer to the contract or a lock mechanism for the deposit amount. This would ensure that the deposit serves its intended purpose.

# `LiquidityPool.sol`

## C-01: Unrestricted initialize Function

**Location:**: initialize function

### PoC:
```solidity 
function testInitializeCanBeCalledMultipleTimes() public {

    LiquidityPool pool = new LiquidityPool();
    pool.initialize(address(0x123));
    pool.initialize(address(0x456)); // This should fail but doesn't

    }
```
### Description:
The initialize function can be called by anyone, multiple times, allowing the re-initialization of the liquidity token.

### Recommendation:
Restrict this function to be callable only once during contract deployment.

### Resolution:
Utilize the initializer modifier correctly or ensure it's only called by the constructor.

# H-01: High Centralization Risk

**Location:**

Various functions (pause, unpause, setMaxDepositsPerUser, etc.)

### PoC:
``` solidity 
function testOwnerCanPauseAndDrainFunds() public {

    LiquidityPool pool = new LiquidityPool();
    pool.deposit(100 ether);
    pool.pause();
    pool.withdrawOwner(100 ether); // Possible exploitation

}
```
### Description:
The contract is highly centralized, giving the owner and admins excessive control, including the ability to pause the contract and withdraw funds.

### Recommendation: 
Decentralize control or add safeguards against misuse.

### Resolution: 
Implement governance mechanisms or timelocks for critical functions.

## M-01: Unclear Liquidity Pool Mechanics

**Location:** Entire contract


### Description:
The contract lacks clear mechanisms for liquidity providers to earn rewards, which is a key feature of liquidity pools in DeFi.

### Recommendation:
Introduce interest or fee distribution mechanisms.

### Resolution:
Implement reward distribution logic for liquidity providers.

## H-02: Manipulable Withdrawal Timings

**Location:**: setWithdrawalCooldown and setWithdrawalWindow functions

### PoC:
``` solidity 
function testOwnerCanManipulateWithdrawalTimings() public {

    LiquidityPool pool = new LiquidityPool();
    pool.setWithdrawalCooldown(30 days); // Extending cooldown arbitrarily
    pool.setWithdrawalWindow(1 hour); // Restricting withdrawal window

}
```
### Description: 
Withdrawal parameters can be changed arbitrarily by the owner or admins, potentially leading to user funds being locked.

### Recommendation: 
Fix these parameters or restrict changes to certain conditions.

### Resolution: 
Implement a governance mechanism or timelock for modifying these parameters.

LendingPool.sol

## H-01 Interest Calculation Simplification
**Location:** Function borrow (Lines where interest rate calculation occurs)

### PoC:
``` solidity 
function testInterestCalculationWithDifferentDurations() public {

    uint256 borrowedAmount = 100 ether;
    uint256 shortTermInterest = calculateExpectedInterest(borrowedAmount, 30 days);
    uint256 longTermInterest = calculateExpectedInterest(borrowedAmount, 365 days);

    vm.startPrank(borrower);
    lendingPool.borrow(borrowedAmount);
    vm.stopPrank();

    // Test for short-term loan interest
    assertEq(lendingPool.interestForDuration(borrowedAmount, 30 days), shortTermInterest, "Incorrect short-term interest calculation");

    // Test for long-term loan interest
    assertEq(lendingPool.interestForDuration(borrowedAmount, 365 days), longTermInterest, "Incorrect long-term interest calculation");

}
```
### Description: 
The interest calculation within the borrow function is overly simplistic, applying a flat interest rate to the borrowed amount without considering the duration of the loan. This approach does not accurately reflect real-world lending scenarios where interest accrues over time.

### Recommendation: 
Implement a more dynamic interest calculation method that factors in the loan duration.

### Resolution: 
Modify the interest calculation in the borrow function to include time-based components, such as the number of days or months the loan is held.

## M-01 Inadequate Loan Repayment Logic

**Location:**Function repay (Lines handling repayment calculations)

### PoC:
``` solidity 
function testPartialRepayment() public {

    uint256 borrowedAmount = 100 ether;
    uint256 partialRepaymentAmount = 50 ether;

    vm.startPrank(borrower);
    lendingPool.borrow(borrowedAmount);
    lendingPool.repay(partialRepaymentAmount);
    vm.stopPrank();

    uint256 expectedRemainingBalance = borrowedAmount - partialRepaymentAmount;
    assertEq(lendingPool.borrowBalance(borrower), expectedRemainingBalance, "Partial repayment logic failed");

}
```
### Description: 
The current repay function does not separate the handling of the principal and interest components of a loan, leading to potential accounting inaccuracies, especially in partial repayment situations.

### Recommendation: 
Separate the management of principal and interest in the loan repayment process.

### Resolution: 
Update the repay function to differentiate between principal and interest repayments and manage them separately.

## M-02 Collateralization Ratio and Bonus Interaction

**Location:** Function borrow (Lines performing collateralization checks)

### PoC:
``` solidity 
function testCollateralizationWithBonus() public {

    uint256 borrowAmount = 100 ether;
    uint256 requiredCollateral = calculateRequiredCollateralWithBonus(borrowAmount);

    vm.startPrank(borrower);
    lendingPool.borrow(borrowAmount);
    vm.stopPrank();

    assertGe(lendingPool.collateralBalance(borrower), requiredCollateral, "Collateralization with bonus not handled correctly");

}
```
### Description: 
The contract uses minCollateralRatio for collateralization checks in the borrow function but does not clearly define how this ratio interacts with the collateralizationBonus.

### Recommendation: 
Clarify the interaction between collateralization ratio and bonus, ensuring both are effectively utilized in loan security.

### Resolution: 
Revise the collateralization check to incorporate both the minimum ratio and the bonus, providing clearer guidelines for their application.

## H-01 Unrestricted Collateral Allowance Management

**Location:** Functions addCollateralAllowance and removeCollateralAllowance

### PoC:
``` solidity 
function testExcessiveCollateralAllowance() public {
uint256 excessiveAllowance = 100000 ether;

    vm.prank(collateralManager);
    lendingPool.addCollateralAllowance(borrower, excessiveAllowance);

    assertLt(lendingPool.collateralAllowance(borrower), excessiveAllowance, "Excessive collateral allowance set");

}
```
### Description:
The addCollateralAllowance function allows a trustedCollateralManager to set collateral allowances without any upper limits, potentially leading to misuse or management errors.

### Recommendation:
Implement limits or additional checks on the allowances that can be set by collateral managers.

### Resolution: 
Modify the addCollateralAllowance function to include checks or caps on the collateral allowance that can be set.

## C-01 Lack of Liquidation Mechanism

**Location:** Entire Contract (Affects overall contract functionality)

### Description: 
The contract does not include a mechanism to handle situations where the collateral value falls below a required threshold, which is a significant risk for a lending platform.

### Recommendation: 
Develop and integrate a liquidation mechanism to manage risks associated with collateral value fluctuations.

### Resolution: 
Implement a function or process that triggers liquidation or collateral adjustment when its value drops below a certain level.

## M-03 Inadequate Control Over Collateral Managers

**Location:** Functions addCollateralManager and

removeCollateralManager

### PoC:
``` solidity 
function testMultipleCollateralManagers() public {

    address additionalManager = address(3);

    vm.prank(owner);
    lendingPool.addCollateralManager(additionalManager);

    assertTrue(lendingPool.trustedCollateralManagers(additionalManager), "Failed to add additional collateral manager");

}
```
### Description: 
The contract lacks sufficient controls or restrictions over the number and actions of trustedCollateralManagers, potentially leading to centralization or mismanagement issues.

### Recommendation: 
Introduce stricter controls or limitations on the appointment and actions of collateral managers.

### Resolution: 
Enhance the functions related to collateral managers with additional checks, limits, or governance mechanisms.
