// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IGBARVault.sol";

contract Deposit is Ownable, ReentrancyGuard {
    uint public depositId;
    IGBARVault public gbarVault;

    event Received(uint _id, address indexed sender, uint amount);
    event DepositReceived(uint _id, address indexed sender, uint amount);

    constructor(address _gbarVault) {
        require(_gbarVault != address(0), "Error: Vault address cannot be 0");
        gbarVault = IGBARVault(_gbarVault);
    }

    receive() external payable {
        depositId++;
        emit Received(depositId, msg.sender, msg.value);
    }

    fallback() external payable {
        depositId++;
        emit Received(depositId, msg.sender, msg.value);
    }

    /**
     * @dev deposit                 Function to deposit the native chain token to the vault
     */
    function deposit() external payable nonReentrant {
        require(gbarVault.getContractBalance() > 0, "Error: No funds in vault");
        depositId++;
        emit DepositReceived(depositId, msg.sender, msg.value);
    }

    /**
     * @dev withdraw                 Function to withdraw the native chain token from the vault
     */
    function withdraw(address payable to) external payable nonReentrant onlyOwner {
        require(address(this).balance > 0, "Error: No funds in contract");
        (bool success, ) = to.call{value: address(this).balance}("");
        require(success, "Error: Transfer failed");
    }

    /**
     * @dev setGBARVault              Function to set the vault address
     */
    function setGBARVault(address _gbarVault) external nonReentrant onlyOwner {
        require(_gbarVault != address(0), "Error: Vault address cannot be 0");
        gbarVault = IGBARVault(_gbarVault);
    }
}
