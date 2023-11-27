// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract LendingPool is Initializable, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public collateralToken;
    IERC20 public borrowedToken;
    mapping(address => uint256) public borrowBalance;
    mapping(address => uint256) public collateralBalance;
    mapping(address => uint256) public collateralAllowance;
    mapping(address => bool) public trustedCollateralManagers;
    uint256 public interestRate;
    uint256 public minCollateralRatio;
    uint256 public maxLoanAmount;
    uint256 public collateralizationBonus;
    uint256[49] __gap;

    event Borrowed(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount);
    event CollateralAdded(address indexed user, uint256 amount);
    event CollateralRemoved(address indexed user, uint256 amount);

    modifier onlyCollateralManager() {
        require(trustedCollateralManagers[msg.sender], "Not a trusted collateral manager");
        _;
    }

    function initialize(
        address _collateralToken,
        address _borrowedToken
    ) public initializer {
        collateralToken = IERC20(_collateralToken);
        borrowedToken = IERC20(_borrowedToken);
        interestRate = 5; // 5% annual interest rate
        minCollateralRatio = 150; // Minimum collateral ratio required (150%)
        maxLoanAmount = 1000 ether; // Maximum loan amount
        collateralizationBonus = 5; // 5% bonus for overcollateralization
        trustedCollateralManagers[msg.sender] = true;
    }

    function setInterestRate(uint256 rate) public onlyOwner {
        interestRate = rate;
    }

    function setMinCollateralRatio(uint256 ratio) public onlyOwner {
        minCollateralRatio = ratio;
    }

    function setMaxLoanAmount(uint256 amount) public onlyOwner {
        maxLoanAmount = amount;
    }

    function setCollateralizationBonus(uint256 bonus) public onlyOwner {
        collateralizationBonus = bonus;
    }

    function addCollateral(uint256 amount) public nonReentrant {
        require(amount > 0, "Collateral amount must be greater than zero");
        require(collateralBalance[msg.sender].add(amount) <= collateralAllowance[msg.sender], "Exceeds collateral allowance");
        collateralToken.transferFrom(msg.sender, address(this), amount);
        collateralBalance[msg.sender] = collateralBalance[msg.sender].add(amount);
        emit CollateralAdded(msg.sender, amount);
    }

    function removeCollateral(uint256 amount) public nonReentrant {
        require(amount > 0, "Collateral amount must be greater than zero");
        require(collateralBalance[msg.sender] >= amount, "Insufficient collateral balance");
        collateralBalance[msg.sender] = collateralBalance[msg.sender].sub(amount);
        collateralToken.transfer(msg.sender, amount);
        emit CollateralRemoved(msg.sender, amount);
    }

    function borrow(uint256 amount) public nonReentrant {
        require(amount > 0, "Borrow amount must be greater than zero");
        require(amount <= maxLoanAmount, "Exceeds maximum loan amount");
        require(collateralBalance[msg.sender] >= amount.mul(minCollateralRatio).div(100), "Insufficient collateral");
        uint256 interest = amount.mul(interestRate).div(100);
        uint256 totalRepayment = amount.add(interest);
        borrowBalance[msg.sender] = borrowBalance[msg.sender].add(totalRepayment);
        borrowedToken.transfer(msg.sender, amount);
        emit Borrowed(msg.sender, totalRepayment);
    }

    function repay(uint256 amount) public nonReentrant {
        require(amount > 0, "Repayment amount must be greater than zero");
        require(borrowBalance[msg.sender] >= amount, "Insufficient borrow balance");
        borrowBalance[msg.sender] = borrowBalance[msg.sender].sub(amount);
        borrowedToken.transferFrom(msg.sender, address(this), amount);
        emit Repaid(msg.sender, amount);
    }

    function addCollateralAllowance(address user, uint256 amount) public onlyCollateralManager {
        collateralAllowance[user] = amount;
    }

    function removeCollateralAllowance(address user) public onlyCollateralManager {
        delete collateralAllowance[user];
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function addCollateralManager(address manager) public onlyOwner {
        trustedCollateralManagers[manager] = true;
    }

    function removeCollateralManager(address manager) public onlyOwner {
        trustedCollateralManagers[manager] = false;
    }
}

