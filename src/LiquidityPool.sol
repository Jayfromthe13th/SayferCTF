// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/Pausable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
contract LiquidityPool is Initializable, Ownable, Pausable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public liquidityToken;
    mapping(address => uint256) public liquidity;
    mapping(address => uint256) public pendingWithdrawals;
    mapping(address => uint256) public totalDeposits;
    mapping(address => bool) public admin;
    uint256 public maxDepositsPerUser;
    uint256 public withdrawalCooldown;
    uint256 public withdrawalWindow;

    event Deposit(address indexed user, uint256 amount);
    event WithdrawalRequested(address indexed user, uint256 amount);

    function initialize(address _liquidityToken) public initializer() {
        liquidityToken = IERC20(_liquidityToken);
        withdrawalCooldown = 7 days; // Cooldown period for withdrawals
        withdrawalWindow = 24 hours; // Window for withdrawing after cooldown
    }

    constructor() {
        maxDepositsPerUser = 1000 ether; // Maximum deposit per user
    }

    function setMaxDepositsPerUser(uint256 amount) public {
        require(msg.sender == owner() || isadmin(msg.sender), "Not the owner or admin");
        maxDepositsPerUser = amount;
    }

    function setWithdrawalCooldown(uint256 cooldown) public {
        require(msg.sender == owner() && isadmin(msg.sender), "Not the owner or admin");
        withdrawalCooldown = cooldown;
    }

    function setWithdrawalWindow(uint256 window) public {
        require(msg.sender == owner() || isadmin(msg.sender), "Not the owner or admin");
        withdrawalWindow = window;
    }

    function deposit(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Deposit amount must be greater than zero");
        require(totalDeposits[msg.sender].add(amount) <= maxDepositsPerUser, "Exceeds maximum deposit limit per user");
        liquidityToken.transferFrom(msg.sender, address(this), amount);
        liquidity[msg.sender] = liquidity[msg.sender].add(amount);
        totalDeposits[msg.sender] = totalDeposits[msg.sender].add(amount);
        emit Deposit(msg.sender, amount);
    }

    function requestWithdrawal(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(liquidity[msg.sender] >= amount, "Insufficient liquidity");
        require(pendingWithdrawals[msg.sender] == 0, "Withdrawal already requested");

        pendingWithdrawals[msg.sender] = amount;
        emit WithdrawalRequested(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant whenNotPaused {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(pendingWithdrawals[msg.sender] > 0, "No withdrawal requested");

        uint256 cooldownEndTime = block.timestamp + withdrawalCooldown;

        if (block.timestamp < cooldownEndTime) {
            require(block.timestamp + withdrawalWindow >= cooldownEndTime, "Withdrawal window closed");
        }

        require(pendingWithdrawals[msg.sender] >= amount, "Insufficient pending withdrawal");

        pendingWithdrawals[msg.sender] = pendingWithdrawals[msg.sender].sub(amount);
        liquidity[msg.sender] = liquidity[msg.sender].sub(amount);
        liquidityToken.transfer(msg.sender, amount);
    }

    function isadmin(address _admin) public view returns (bool) {
        return admin[_admin];
    }

    function addAdmin(address _admin) public onlyOwner {
        admin[_admin] = true;
    }

    function removeAdmin(address _admin) public onlyOwner {
        admin[_admin] = false;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function withdrawOwner(uint256 amount) public onlyOwner {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        
        liquidityToken.transfer(msg.sender, amount);
    }
}
