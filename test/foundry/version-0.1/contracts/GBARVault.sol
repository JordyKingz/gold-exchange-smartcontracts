// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./interfaces/IGBAR.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IGoldStakeVault.sol";
import "./interfaces/IGBARVault.sol";

contract GBARVault is IGBARVault, Ownable {
    IGBAR public IGbarToken;

    event WithdrawnTo(address to, uint amount);
    event Deposited(address from, uint amount);

    constructor(address gbar) {
        require(gbar != address(0), "Error: GBAR address cannot be 0");
        IGbarToken = IGBAR(gbar);
    }

    /**
     * @dev getContractBalance          Function to get the contract balance
     *
     * @return                          Returns the contract balance
     */
    function getContractBalance() external view returns(uint) {
        return IGbarToken.balanceOf(address(this));
    }

    /**
     * @dev deposit                     Function to deposit GBAR to the vault
     *
     * @param amount                    The amount to deposit
     */
    function deposit(uint amount) public {
        require(amount > 0, "Error: Amount must be greater than 0");
        require(IGbarToken.allowance(_msgSender(), address(this)) >= amount, "Error: Transfer of token has not been approved");
        IGbarToken.transferFrom(_msgSender(), address(this), amount);
        emit Deposited(_msgSender(), amount);
    }

    /**
     * @dev withdrawTo                  Function to withdraw GBAR from the vault
     *
     * @notice                          This function can only be called by the owner
     *
     * @param to                        The address to send the GBAR to
     * @param amount                    The amount to withdraw
     */
    function withdrawTo(address to, uint amount) external onlyOwner {
        require(to != address(0), "Error: Cannot send to 0 address");
        require(IGbarToken.balanceOf(address(this)) >= amount, "Error: Not enough funds in vault");
        IGbarToken.transfer(to, amount);
        emit WithdrawnTo(to, amount);
    }

    /**
     * @dev setGBAR                     Function to set the GBAR address
     *
     * @notice                          This function can only be called by the owner
     *
     * @param gbar                      The GBAR address
     */
    function setGBAR(address gbar) external onlyOwner {
        require(gbar != address(0), "Error: GBAR address cannot be 0");
        IGbarToken = IGBAR(gbar);
    }
}