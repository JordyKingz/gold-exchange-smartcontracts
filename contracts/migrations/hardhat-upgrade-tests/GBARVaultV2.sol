// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "../../interfaces/GbarInterface.sol";
import "../../interfaces/GbarVaultInterface.sol";

/// @notice used for testing upgrade contract
contract GBARVaultV2 is GbarVaultInterface, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event WithdrawnTo(address to, uint amount);
    event Deposited(address from, uint amount);
    event GBARAddressChanged(address gbar);

    error AmountCannotBeZero();
    error AddressCannotBeZero();
    error AmountExceedsAllowance();
    error AmountExceedsBalance();

    GbarInterface public GbarToken;

    function initialize(address gbar) public initializer {
        require(gbar != address(0), "Error: GBAR address cannot be 0");

        __Ownable_init();
        __ReentrancyGuard_init();
        GbarToken = GbarInterface(gbar);
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function newFunction() public pure returns (string memory) {
        return "newFunction";
    }

    /**
     * @dev getContractBalance          Function to get the contract balance
     *
     * @return                          Returns the contract balance
     */
    function getContractBalance() external view returns(uint) {
        return GbarToken.balanceOf(address(this));
    }

    /**
     * @dev deposit                     Function to deposit GBAR to the vault
     *
     * @param amount                    The amount to deposit
     */
    function deposit(uint amount) public {
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GbarToken.allowance(_msgSender(), address(this))) {
            revert AmountExceedsAllowance();
        }

        GbarToken.transferFrom(_msgSender(), address(this), amount);
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
    function withdrawTo(address to, uint amount) external onlyOwner nonReentrant {
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (amount > GbarToken.balanceOf(address(this))) {
            revert AmountExceedsBalance();
        }
        GbarToken.transfer(to, amount);
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
        if (gbar == address(0)) {
            revert AddressCannotBeZero();
        }
        GbarToken = GbarInterface(gbar);
        emit GBARAddressChanged(gbar);
    }
}