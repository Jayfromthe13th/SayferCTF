// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

contract Token is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 public constant maxSupply = 1000000 ether; // Maximum token supply
    uint256 public totalBurned;
    uint256 public burnFee;
    uint256 public transferFee;
    mapping(address => uint256) public totalTransferred;
    mapping(address => uint256) public totalFees;

    event Burned(address indexed burner, uint256 amount);
    event FeeCollected(address indexed collector, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) ERC20(_name, _symbol) {
        _mint(msg.sender, _initialSupply);
        burnFee = 1; // 1% burn fee on transfers
        transferFee = 2; // 2% transfer fee on transfers
    }

    function burn(uint256 amount) public nonReentrant {
        require(amount > 0, "Burn amount must be greater than zero");
        require(totalSupply().sub(totalBurned) >= amount, "Exceeds available supply");

        _burn(msg.sender, amount);
        totalBurned = totalBurned.add(amount);
        emit Burned(msg.sender, amount);
    }

    function setBurnFee(uint256 fee) public onlyOwner {
        require(fee <= 5, "Burn fee can't exceed 5%");
        burnFee = fee;
    }

    function setTransferFee(uint256 fee) public onlyOwner {
        require(fee <= 5, "Transfer fee can't exceed 5%");
        transferFee = fee;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 feeAmount = amount.mul(transferFee).div(100);
        uint256 netAmount = amount.sub(feeAmount);

        super.transfer(to, netAmount);

        // Burn fee
        if (burnFee > 0) {
            uint256 burnAmount = amount.mul(burnFee).div(100);
            _burn(msg.sender, burnAmount);
            totalBurned = totalBurned.add(burnAmount);
            emit Burned(msg.sender, burnAmount);
        }

        totalTransferred[msg.sender] = totalTransferred[msg.sender].add(amount);
        totalFees[msg.sender] = totalFees[msg.sender].add(feeAmount);

        emit FeeCollected(msg.sender, feeAmount);

        return true;
    }
}
