// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IFeeProvider} from "./interfaces/IFeeProvider.sol";
import { IGBARVault } from "./interfaces/IGBARVault.sol";
import "./models/RetrievalRequest.sol";

contract GBAR is ERC20, Ownable, ReentrancyGuard {
    address public FEE_DISTRIBUTOR;
    IFeeProvider public FEE_PROVIDER;
    IGBARVault public GBAR_VAULT;

    RetrievalRequest[] public retrievalRequests;
    address[] public retrievalGuards;
    uint8 public numConfirmationsRequired;

    mapping(address => bool) public excludedFromFee;
    mapping(address => bool) public blacklist;
    mapping(uint256 => mapping(address => bool)) public retrievalRequestConfirmed;
    mapping(address => bool) public isRetrievalGuard;

    uint256 private _totalSupply;

    event Burned(address indexed from, uint amount);
    event MintedAndTransferred(address indexed to, uint amount);
    event TransferredFromWallet(address indexed from, address indexed to, uint amount);
    event CreateRetrievalRequest(address indexed retrievalGuard, uint256 indexed txIndex, address indexed from, uint amount);
    event ConfirmRetrievalRequest(address indexed retrievalGuard, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed retrievalGuard, uint256 indexed txIndex);

    constructor(address feeProvider, uint8 _numOfConfirmationsRequired, address[] memory retrievalGuardList) ERC20("GBAR", "GBAR") {
        require(_numOfConfirmationsRequired > 1, "numOfConfirmationsRequired must be greater than 1");
        require(_numOfConfirmationsRequired == retrievalGuardList.length, "numOfConfirmationsRequired must be equal to the number of retrieval guards");
        FEE_PROVIDER = IFeeProvider(feeProvider);
        numConfirmationsRequired = _numOfConfirmationsRequired;

        for (uint i = 0; i < retrievalGuardList.length; ++i) {
            address retrievalGuard = retrievalGuardList[i];

            require(retrievalGuard != address(0), "invalid retrieval guard");
            require(!isRetrievalGuard[retrievalGuard], "retrieval guard not unique");

            isRetrievalGuard[retrievalGuard] = true;
            retrievalGuards.push(retrievalGuard);
        }
    }

    /**
     * @dev onlyRetrievalGuard                  Modifier to ensure only an address that is present
     *                                          in the retrievalguard list can execute
     */
    modifier onlyRetrievalGuard() {
        require(isRetrievalGuard[_msgSender()], "not retrieval guard");
        _;
    }

    /**
     * @dev retrievalRequestExists              Modifier to ensure a retrieval request
     *                                          exists at the given index
     */
    modifier retrievalRequestExists(uint index) {
        require(index < retrievalRequests.length, "request does not exist");
        _;
    }

    /**
     * @dev retrievalRequestNotExecuted         Modifier to ensure a retrieval request
     *                                          at the given index is not already executed
     */
    modifier retrievalRequestNotExecuted(uint index) {
        require(!retrievalRequests[index].executed, "request already executed");
        _;
    }

    /**
     * @dev retrievalRequestNotConfirmed        Modifier to ensure a retrieval request
     *                                          at the given index is not confirmed by the caller
     */
    modifier retrievalRequestNotConfirmed(uint index) {
        require(!retrievalRequestConfirmed[index][_msgSender()], "request already confirmed");
        _;
    }

    /**
     * @dev getRetrievalRequest                 Function to get retrievalRequest at the given index
     *
     * @param index                             The index of the retrieval request
     *
     * @return RetrievalRequest                 The retrieval request at the given index
     */
    function getRetrievalRequest(uint index) public view retrievalRequestExists(index) returns(RetrievalRequest memory) {
        return retrievalRequests[index];
    }

    /**
     * @dev getRetrievalRequestCount            Function to get the number of existing retrieval requests
     */
    function getRetrievalRequestCount() public view returns (uint) {
        return retrievalRequests.length;
    }

    /**
     * @dev getRetrievalRetrievalGuardsCount    Function to get the number of existing retrieval guards
     */
    function getRetrievalRetrievalGuardsCount() public view returns (uint) {
        return retrievalGuards.length;
    }

    /**
     * @dev decimals                            Function to get the number of decimals
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @dev mint                            Function to mint GBAR tokens
     *
     * @notice                              GBAR is minted based on the amount of gold stored in the vault.
     *                                      GBAR is minted to the GBAR vault,
     *                                      from where it is bought by and transferred to the buyer.
     *
     * @param amount                        The amount of GBAR to mint
     *
     * @return bool                         True if the minting was successful
     */
    function mint(uint amount) public onlyOwner nonReentrant returns(bool) {
        require(address(GBAR_VAULT) != address(0), "GBAR_VAULT not set");
        require(amount > 0, "Error: value must be greater than 0");
        _totalSupply += amount;
        _mint(address(GBAR_VAULT), amount); // minted tokens are transferred to the vault
        return true;
    }

    /**
     * @dev transfer                        Override Function to transfer GBAR tokens
     *
     * @notice                              GBAR is transferred to the recipient
     *                                      Not callable by blacklisted addresses
     *                                      When sender and receiver are not excluded from fee
     *                                      A fee is deducted from the transfer amount and sent to the fee distributor
     *                                      Fee is distributor over GOLD stakers
     *
     * @param to                            The address to transfer to
     * @param amount                        The amount of GBAR to mint
     *
     * @return bool                         True if the minting was successful
     */
    function transfer(address to, uint amount) public override nonReentrant returns(bool) {
        require(amount > 0, "Error: value must be greater than 0");
        require(to != address(0), "Error: to cannot be the null address");
        require(!blacklist[_msgSender()] && !blacklist[to], "blacklisted transaction blocked");

        uint fee = _getFeeFor(amount);

        if (excludedFromFee[_msgSender()] || excludedFromFee[to]) fee = 0;

        uint toTransfer = amount - fee;

        // transfer fee to the fee distributor
        if (fee > 0) _transfer(_msgSender(), FEE_DISTRIBUTOR, fee);

        _transfer(_msgSender(), to, toTransfer);
        return true;
    }

    /**
     * @dev transferFrom                    Override Function to transfer GBAR tokens from an address
     *
     * @notice                              GBAR is transferred to the recipient
     *                                      Not callable by blacklisted addresses
     *                                      When sender and receiver are not excluded from fee
     *                                      A fee is deducted from the transfer amount and sent to the fee distributor
     *                                      Fee is distributor over GOLD stakers
     *
     * @param from                          The address to transfer from
     * @param to                            The address to transfer to
     * @param amount                        The amount of GBAR to mint
     *
     * @return bool                         True if the minting was successful
     */
    function transferFrom(address from, address to, uint amount) public override nonReentrant returns(bool) {
        require(amount > 0, "Error: value must be greater than 0");
        require(to != address(0), "Error: to cannot be the null address");
        require(!blacklist[_msgSender()] && !blacklist[from] && !blacklist[to], "blacklisted transaction blocked");
        _spendAllowance(from, _msgSender(), amount);

        uint fee = _getFeeFor(amount);

        if (excludedFromFee[from] || excludedFromFee[to] || excludedFromFee[_msgSender()]) fee = 0;

        uint toTransfer = amount - fee;

        // transfer fee to the fee distributor
        if (fee > 0) _transfer(from, FEE_DISTRIBUTOR, fee);

        _transfer(from, to, toTransfer);
        return true;
    }

    /**
     * @dev addBlacklist                    Function to add an address to the blacklist
     *
     * @notice                              Only callable by the owner
     *
     * @param wallet                        The address to blacklist
     */
    function addBlacklist(address wallet) external onlyOwner {
        require(wallet != address(0), "Error: to cannot be the null address");
        blacklist[wallet] = true;
    }

    /**
     * @dev removeBlacklist                 Function to remove an address from the blacklist
     *
     * @notice                              Only callable by the owner
     *
     * @param wallet                        The address to blacklist
     */
    function removeBlacklist(address wallet) external onlyOwner {
        require(wallet != address(0), "Error: to cannot be the null address");
        blacklist[wallet] = false;
    }

    /**
     * @dev setFeeDistributor               Function to set the fee distributor
     *
     * @notice                              Only callable by the owner
     *
     * @param feeDistributor                The address of the new fee distributor
     */
    function setFeeDistributor(address feeDistributor) external onlyOwner {
        require(feeDistributor != address(0), "Error: to cannot be the null address");
        FEE_DISTRIBUTOR = feeDistributor;
    }

    /**
     * @dev setGBARVault                Function to set the GBAR vault
     *
     * @notice                          Only callable by the owner
     *
     * @param vault                     The address of the new GBAR vault
     */
    function setGBARVault(address vault) external onlyOwner {
        require(vault != address(0), "Error: to cannot be the null address");
        GBAR_VAULT = IGBARVault(vault);
    }

    /**
     * @dev setFeeProvider              Function to set the fee provider
     *
     * @notice                          Only callable by the owner
     *
     * @param feeProvider               The address of the new fee provider
     */
    function setFeeProvider(address feeProvider) external onlyOwner {
        require(feeProvider != address(0), "Error: to cannot be the null address");
        FEE_PROVIDER = IFeeProvider(feeProvider);
    }

    /**
     * @dev addFeeExclusion             Function to add an address to the fee exclusion list
     *
     * @notice                          Only callable by the owner
     *
     * @param toExclude                 The address to add to the fee exclusion list
     */
    function addFeeExclusion(address toExclude) external onlyOwner {
        require(toExclude != address(0), "Error: to cannot be the null address");
        excludedFromFee[toExclude] = true;
    }

    /**
     * @dev removeFeeExclusion          Function to remove an address from the fee exclusion list
     *
     * @notice                          Only callable by the owner
     *
     * @param toExclude                 The address to remove from the fee exclusion list
     */
    function removeFeeExclusion(address toExclude) external onlyOwner {
        require(toExclude != address(0), "Error: to cannot be the null address");
        excludedFromFee[toExclude] = false;
    }

    /**
     * @dev burn                        Function to burn GBAR tokens
     *
     * @notice                          Only callable by the owner
     *                                  Only burnable for blacklisted addresses
     *
     * @param from                      The address from which the tokens need to be burned
     * @param amount                    The amount of tokens that need to be burned
     */
    function burn(address from, uint amount) external onlyOwner nonReentrant {
        require(amount > 0, "Error: amount must be greater than zero");
        require(blacklist[from] == true, "Error: wallet is not blacklisted");

        _totalSupply -= amount;
        _burn(from, amount);

        emit Burned(from, amount);
    }

    /**
     * @dev createRetrievalRequest      Function to create a retrieval request
     *
     * @notice                          Only callable by retrieval guards
     *
     * @param from                      The address from which the tokens need to be retrieved
     * @param amount                    The amount of tokens that need to be retrieved
     */
    function createRetrievalRequest(address from, uint amount) external onlyRetrievalGuard() nonReentrant {
        require(from != address(0), "Error: from cannot be the null address");
        require(amount > 0, "Error: amount must be greater than zero");
        uint txIndex = retrievalRequests.length;

        retrievalRequests.push(
            RetrievalRequest({
                from: from,
                amount: amount,
                numConfirmations: 0,
                executed: false
            })
        );

        emit CreateRetrievalRequest(_msgSender(), txIndex, from, amount);
    }

    /**
     * @dev confirmRetrievalRequest     Function to confirm a retrieval request
     *
     * @notice                          Only callable by retrieval guards
     *                                  Only callable if the retrieval request exists
     *                                  Only callable if the retrieval request has not been executed
     *                                  Only callable if the retrieval request has not been confirmed by the sender
     *
     * @param index                     The index at which the retrieval request exists
     */
    function confirmRetrievalRequest(uint index)
    external
    onlyRetrievalGuard()
    retrievalRequestExists(index)
    retrievalRequestNotExecuted(index)
    retrievalRequestNotConfirmed(index)
    nonReentrant
    {
        RetrievalRequest storage retrievalRequest = retrievalRequests[index];
        retrievalRequest.numConfirmations += 1;
        retrievalRequestConfirmed[index][_msgSender()] = true;

        emit ConfirmRetrievalRequest(_msgSender(), index);
    }

    /**
     * @dev executeRetrievalRequest     Function to execute a retrieval request that has been confirmed
     *
     * @notice                          Only callable by retrieval guards
     *                                  Only callable if the retrieval request exists
     *                                  Only callable if the retrieval request has not been executed
     *
     * @param index                     The index at which the retrieval request exists
     */
    function executeRetrievalRequest(uint index)
    external
    onlyRetrievalGuard()
    retrievalRequestExists(index)
    retrievalRequestNotExecuted(index)
    nonReentrant
    {
        RetrievalRequest storage retrievalRequest = retrievalRequests[index];

        require(
            retrievalRequest.numConfirmations >= numConfirmationsRequired,
            "not enough confirmations"
        );

        retrievalRequest.executed = true;
        blacklist[retrievalRequest.from] = true;
        _burn(retrievalRequest.from, retrievalRequest.amount);

        emit TransferredFromWallet(retrievalRequest.from, _msgSender(), retrievalRequest.amount);
    }

    /**
     * @dev revokeConfirmation          Function to revoke a confirmation for a retrieval request
     *
     * @notice                          Only callable by retrieval guards
     *                                  Only callable if the retrieval request exists
     *                                  Only callable if the retrieval request has not been executed
     *
     * @param index                     The index at which the retrieval request exists
     */
    function revokeConfirmation(uint index)
    external
    onlyRetrievalGuard()
    retrievalRequestExists(index)
    retrievalRequestNotExecuted(index)
    nonReentrant
    {
        require(retrievalRequestConfirmed[index][_msgSender()], "request not confirmed");

        RetrievalRequest storage retrievalRequest = retrievalRequests[index];
        retrievalRequest.numConfirmations -= 1;
        retrievalRequestConfirmed[index][_msgSender()] = false;

        emit RevokeConfirmation(_msgSender(), index);
    }

    /**
     * @dev _getFeeFor                  Function to get the fee for a given value
     *
     * @param value                     The value for which the fee needs to be calculated
     *
     * @return uint                  The fee for the given value
     */
    function _getFeeFor(uint value) internal view returns (uint) {
        return FEE_PROVIDER.getFee(value);
    }
}
