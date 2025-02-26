// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract USDCAcceptor is Ownable {
    IERC20 public immutable usdc;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);

    constructor(address _usdcAddress) {
        require(_usdcAddress != address(0), "Invalid USDC address");
        usdc = IERC20(_usdcAddress);
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");

        // Transfer USDC from sender to this contract (requires prior approval)
        require(usdc.transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Update balance
        balances[msg.sender] += amount;

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Update balance
        balances[msg.sender] -= amount;

        // Transfer USDC back to the user
        require(usdc.transfer(msg.sender, amount), "Transfer failed");

        emit Withdrawal(msg.sender, amount);
    }

    function getContractBalance() external view returns (uint256) {
        return usdc.balanceOf(address(this));
    }

    function emergencyWithdraw(address to, uint256 amount) external onlyOwner {
        require(usdc.transfer(to, amount), "Emergency transfer failed");
    }
}
