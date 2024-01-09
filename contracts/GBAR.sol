// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/FeeProviderInterface.sol";
import "./interfaces/GbarVaultInterface.sol";
import "./interfaces/GoldOracleInterface.sol";
import "./structs/GBARStructs.sol";
import "./interfaces/GoldInterface.sol";

contract GBAR is Initializable, ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    event Burned(address indexed from, uint256 amount);
    event MintedAndTransferred(address indexed to, uint256 amount);
    event TransferredFromWallet(address indexed from, address indexed to, uint256 amount);
    event CreateRetrievalRequest(address indexed retrievalGuard, uint256 indexed txIndex, address indexed from, uint256 amount);
    event ConfirmRetrievalRequest(address indexed retrievalGuard, uint256 indexed txIndex);
    event RevokeConfirmation(address indexed retrievalGuard, uint256 indexed txIndex);
    event Stabilized(uint256 gbarTotalSupply, uint256 gbarValue, uint256 goldPriceGram, uint256 totalValueGold);

    error NotTheGoldContract();
    error NotTheRetrievalGuard();
    error RetrievalRequestDoesNotExist();
    error RetrievalRequestAlreadyExecuted();
    error RetrievalRequestAlreadyConfirmed();
    error GBARVaultNotSet();
    error GoldContractNotSet();
    error AmountCannotBeZero();
    error AddressCannotBeZero();
    error AddressNotBlacklisted();
    error BlacklistedTransaction();
    error NotEnoughConfirmations();
    error RequestNotConfirmed();
    error StabilizeTimestampNoPassed();
    error StabilizeNotPossible();

    address public FeeDistributor;
    GoldInterface public GoldToken;
    FeeProviderInterface public FeeProvider;
    GbarVaultInterface public GbarVault;
    GoldOracleInterface public GoldOracle;

    RetrievalRequest[] public retrievalRequests;
    address[] public retrievalGuards;
    uint8 public numConfirmationsRequired;

    uint public stabilizationTimestamp;

    mapping(address => bool) public excludedFromFee;
    mapping(address => bool) public blacklist;
    mapping(uint256 => mapping(address => bool)) public retrievalRequestConfirmed;
    mapping(address => bool) public isRetrievalGuard;

    uint256 private _totalSupply;

    function initialize(address feeProvider, address goldToken, address oracle, uint8 _numOfConfirmationsRequired, address[] memory retrievalGuardList) public initializer {
        require(_numOfConfirmationsRequired > 1, "numOfConfirmationsRequired must be greater than 1");
        require(_numOfConfirmationsRequired == retrievalGuardList.length, "numOfConfirmationsRequired must be equal to the number of retrieval guards");
        __ERC20_init("GBAR", "GBAR");
        __Ownable_init();
        __ReentrancyGuard_init();

        FeeProvider = FeeProviderInterface(feeProvider);
        GoldToken = GoldInterface(goldToken);
        GoldOracle = GoldOracleInterface(oracle);

        numConfirmationsRequired = _numOfConfirmationsRequired;

        stabilizationTimestamp = block.timestamp + 28 days; // every 28 days we can stabilize gbar
        uint guardListLength = retrievalGuardList.length;
        for (uint i = 0; i < guardListLength; ++i) {
            address retrievalGuard = retrievalGuardList[i];

            require(retrievalGuard != address(0), "invalid retrieval guard");
            require(!isRetrievalGuard[retrievalGuard], "retrieval guard not unique");

            isRetrievalGuard[retrievalGuard] = true;
            retrievalGuards.push(retrievalGuard);
        }
    }

    /// @notice omits the constructor when deployed on hedera
    /// needed when deployed to ethereum
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    /**
     * @dev onlyGoldContract                    Modifier to ensure only the gold contract can execute
     */
    modifier onlyGoldContract() {
        if (_msgSender() != address(GoldToken))
            revert NotTheGoldContract();
        _;
    }

    /**
     * @dev onlyRetrievalGuard                  Modifier to ensure only an address that is present
     *                                          in the retrievalguard list can execute
     */
    modifier onlyRetrievalGuard() {
        if (!isRetrievalGuard[_msgSender()])
            revert NotTheRetrievalGuard();
        _;
    }

    /**
     * @dev retrievalRequestExists              Modifier to ensure a retrieval request
     *                                          exists at the given index
     */
    modifier retrievalRequestExists(uint index) {
        if (index >= retrievalRequests.length)
            revert RetrievalRequestDoesNotExist();
        _;
    }

    /**
     * @dev retrievalRequestNotExecuted         Modifier to ensure a retrieval request
     *                                          at the given index is not already executed
     */
    modifier retrievalRequestNotExecuted(uint index) {
        if (retrievalRequests[index].executed)
            revert RetrievalRequestAlreadyExecuted();
        _;
    }

    /**
     * @dev retrievalRequestNotConfirmed        Modifier to ensure a retrieval request
     *                                          at the given index is not confirmed by the caller
     */
    modifier retrievalRequestNotConfirmed(uint index) {
        if (retrievalRequestConfirmed[index][_msgSender()])
            revert RetrievalRequestAlreadyConfirmed();
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
        if (address(GbarVault) == address(0)) {
            revert GBARVaultNotSet();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        _totalSupply += amount;
        _mint(address(GbarVault), amount); // minted tokens are transferred to the vault
        return true;
    }

    /**
     * @dev goldValueMint                   Function called by gold contract, to mint GBAR tokens
     *
     * @notice                              Gold contract can call this function to mint 85% value
     *                                      of the gold value in GBAR tokens.
     *
     * @param amount                        The amount of GBAR to mint
     *
     * @return bool                         True if the minting was successful
     */
    function goldValueMint(uint amount) public onlyGoldContract nonReentrant returns(bool) {
        if (address(GbarVault) == address(0)) {
            revert GBARVaultNotSet();
        }
        if (address(GoldToken) == address(0)) {
            revert GoldContractNotSet();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }

        _totalSupply += amount;
        _mint(address(GbarVault), amount); // minted tokens are transferred to the vault
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
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (blacklist[_msgSender()] || blacklist[to]) {
            revert BlacklistedTransaction();
        }

        uint fee = _getFeeFor(amount);

        if (excludedFromFee[_msgSender()] || excludedFromFee[to]) fee = 0;

        uint toTransfer = amount - fee;

        // transfer fee to the fee distributor
        if (fee > 0) _transfer(_msgSender(), FeeDistributor, fee);

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
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (blacklist[_msgSender()] || blacklist[from] || blacklist[to]) {
            revert BlacklistedTransaction();
        }

        _spendAllowance(from, _msgSender(), amount);

        uint fee = _getFeeFor(amount);

        if (excludedFromFee[from] || excludedFromFee[to] || excludedFromFee[_msgSender()]) fee = 0;

        uint toTransfer = amount - fee;

        // transfer fee to the fee distributor
        if (fee > 0) _transfer(from, FeeDistributor, fee);

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
        if (wallet == address(0)) {
            revert AddressCannotBeZero();
        }
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
        if (wallet == address(0)) {
            revert AddressCannotBeZero();
        }
        blacklist[wallet] = false;
    }

    /**
     * @dev setFeeDistributor               Function to set the fee distributor
     *
     * @notice                              Only callable by the owner
     *
     * @param _feeDistributor                The address of the new fee distributor
     */
    function setFeeDistributor(address _feeDistributor) external onlyOwner {
        if (_feeDistributor == address(0)) {
            revert AddressCannotBeZero();
        }
        FeeDistributor = _feeDistributor;
    }

    /**
     * @dev setGoldContract               Function to set the gold contract
     *
     * @notice                            Only callable by the owner
     *
     * @param goldContract                The address of the new gold contract
     */
    function setGoldContract(address goldContract) external onlyOwner {
        if (goldContract == address(0)) {
            revert AddressCannotBeZero();
        }
        GoldToken = GoldInterface(goldContract);
    }

    /**
     * @dev setGBARVault                Function to set the GBAR vault
     *
     * @notice                          Only callable by the owner
     *
     * @param vault                     The address of the new GBAR vault
     */
    function setGBARVault(address vault) external onlyOwner {
        if (vault == address(0)) {
            revert AddressCannotBeZero();
        }
        GbarVault = GbarVaultInterface(vault);
    }

    /**
     * @dev setFeeProvider              Function to set the fee provider
     *
     * @notice                          Only callable by the owner
     *
     * @param _feeProvider               The address of the new fee provider
     */
    function setFeeProvider(address _feeProvider) external onlyOwner {
        if (_feeProvider == address(0)) {
            revert AddressCannotBeZero();
        }
        FeeProvider = FeeProviderInterface(_feeProvider);
    }

    /** todo add unit tests
     * @dev setGoldOracle               Function to set the gold oracle
     *
     * @notice                          Only callable by the owner
     *
     * @param _oracle                   The address of the new gold oracle
     */
    function setGoldOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) {
            revert AddressCannotBeZero();
        }
        GoldOracle = GoldOracleInterface(_oracle);
    }

    /**
     * @dev addFeeExclusion             Function to add an address to the fee exclusion list
     *
     * @notice                          Only callable by the owner
     *
     * @param toExclude                 The address to add to the fee exclusion list
     */
    function addFeeExclusion(address toExclude) external onlyOwner {
        if (toExclude == address(0)) {
            revert AddressCannotBeZero();
        }
        excludedFromFee[toExclude] = true;
    }

    /**
     * @dev removeFeeExclusion          Function to remove an address from the fee exclusion list
     *
     * @notice                          Only callable by the owner
     *
     * @param toRemove                  The address to remove from the fee exclusion list
     */
    function removeFeeExclusion(address toRemove) external onlyOwner {
        if (toRemove == address(0)) {
            revert AddressCannotBeZero();
        }
        excludedFromFee[toRemove] = false;
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
        if (from == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
        if (blacklist[from] == false) {
            revert AddressNotBlacklisted();
        }

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
        if (from == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountCannotBeZero();
        }
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
     * @param index                      The index at which the retrieval request exists
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

        if (retrievalRequest.numConfirmations < numConfirmationsRequired) {
            revert NotEnoughConfirmations();
        }

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
        if(retrievalRequestConfirmed[index][_msgSender()] == false) {
            revert RequestNotConfirmed();
        }

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
     * @return uint                     The fee for the given value
     */
    function _getFeeFor(uint value) internal view returns (uint) {
        return FeeProvider.getFee(value);
    }

    /**
     * @dev stabilize                   Function to stabilize the GBAR token
     *
     * @notice                          TotalSupply of GBAR can only be 85% of the
     *                                  total value of GOLD in the vault
     *                                  Based on calculation of the current gold price
     *                                  we burn or mint GBAR tokens if necessary
     *
     */
    function stabilize() external onlyOwner {
        if (stabilizationTimestamp > block.timestamp) {
            revert StabilizeTimestampNoPassed();
        }
        uint vaultBalance = balanceOf(address(GbarVault));
        uint goldTotalSupply = GoldToken.totalSupply();
        uint gbarTotalSupply = totalSupply();

        // check if we can stabilize
        if (vaultBalance == 0 || gbarTotalSupply == 0 || goldTotalSupply == 0) {
            revert StabilizeNotPossible();
        }

        (uint goldPriceGram,
        uint totalValueGold,
        uint gbarValue) = GoldOracle.getGoldGbarConversion(goldTotalSupply);

        // more supply than allowed
        if (gbarTotalSupply > gbarValue) {
            uint amountToBurn = gbarTotalSupply - gbarValue;
            // check if we can burn from gbarVault
            if (vaultBalance >= amountToBurn) {
                _burn(address(GbarVault), amountToBurn);
            } else {
                // burn vault balance, rest of gbar is in circulation
                _burn(address(GbarVault), vaultBalance);
            }
        } else if (gbarValue > gbarTotalSupply) {
            // less supply than allowed
            uint amountToMint = gbarValue - gbarTotalSupply;
            mint(amountToMint);
        }
        stabilizationTimestamp = block.timestamp + 28 days;

        emit Stabilized(gbarTotalSupply, gbarValue, goldPriceGram, totalValueGold);
    }
}
