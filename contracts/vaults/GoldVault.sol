// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../interfaces/GoldInterface.sol";
import "../interfaces/VaultInterface.sol";

contract GoldVault is VaultInterface, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event WithdrawnTo(address to, uint amount);
    event Deposited(address from, uint amount);
    event AddressChanged(address newToken);

    error AmountCannotBeZero();
    error AddressCannotBeZero();
    error AmountExceedsAllowance();
    error AmountExceedsBalance();

    GoldInterface public GoldToken;

    function initialize(address gold) public initializer {
        require(gold != address(0), "Error: GOLD address cannot be 0");

        __Ownable_init();
        __ReentrancyGuard_init();
        GoldToken = GoldInterface(gold);
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev getContractBalance          Function to get the contract balance
     *
     * @return                          Returns the contract balance
     */
    function getContractBalance() external view returns(uint) {
        return GoldToken.balanceOf(address(this));
    }

    /**
     * @dev deposit                     Function to deposit GOLD to the vault
     *
     * @param amount                    The amount to deposit
     */
    function deposit(uint amount) public {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GoldToken.allowance(_msgSender(), address(this))) {
            revert AmountExceedsAllowance();
        }

        GoldToken.transferFrom(_msgSender(), address(this), amount);
        emit Deposited(_msgSender(), amount);
    }

    /**
     * @dev withdrawTo                  Function to withdraw GOLD from the vault
     *
     * @notice                          This function can only be called by the owner
     *
     * @param to                        The address to send the GOLD to
     * @param amount                    The amount to withdraw
     */
    function withdrawTo(address to, uint amount) external onlyOwner nonReentrant {
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GoldToken.balanceOf(address(this))) {
            revert AmountExceedsBalance();
        }
        GoldToken.transfer(to, amount);
        emit WithdrawnTo(to, amount);
    }

    /**
     * @dev setGold                     Function to set the GOLD address
     *
     * @notice                          This function can only be called by the owner
     *
     * @param gold                      The GOLD address
     */
    function setGold(address gold) external onlyOwner {
        if (gold == address(0)) {
            revert AddressCannotBeZero();
        }
        GoldToken = GoldInterface(gold);
        emit AddressChanged(gold);
    }
}