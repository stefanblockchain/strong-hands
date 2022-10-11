// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFeeStrategy.sol";
import "./interfaces/IWETH.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IAToken.sol";

//@title Strong hand contract
// @author Stefan Plazic
// @notice This contract is for depositing ether to Avve contract, and making user wait lock time (to avoid fee) before removing their deposit
contract StrongHand is Ownable {
    uint256 private lockTime;
    uint256 private totalSupply;
    uint256 private totalDividends;
    uint256 private unclaimedDividends;
    uint256 private constant POINT_MULTIPLIER = 10e18;
    uint256 private constant DUST = 4 wei;

    IPoolAddressesProvider private immutable poolAddressesProvider;
    IAToken private immutable iAToken;
    IFeeStrategy private feeStrategy;
    IWETH private immutable weth;

    struct UserDeposit {
        uint256 reedemTime;
        uint256 lastDivident;
        uint256 balance;
    }

    mapping(address => UserDeposit) private userDeposits;

    /* EVENTS */
    event DepositEvent(
        address indexed sender,
        uint256 amount,
        uint256 reedemTime
    );
    event ReedemEvent(address indexed reedemer, uint256 amount);
    event OwnerInterestEvent(address indexed owner, uint256 amount);

    /* ERRORS */
    error ValueSentIsZeroError();
    error NoTokensToReedemError(address account);
    error NoInterestToReedemError(address owner);
    error SendingEtherFailedError(address account);
    error ZeroAddressError();

    constructor(
        uint256 _lockTime,
        address _poolAddressesProviderAddress,
        address _iATokenAddress,
        address _feeStrategyAddress,
        address _wethAddress
    ) {
        lockTime = _lockTime;
        poolAddressesProvider = IPoolAddressesProvider(
            _poolAddressesProviderAddress
        );
        iAToken = IAToken(_iATokenAddress);
        feeStrategy = IFeeStrategy(_feeStrategyAddress);
        weth = IWETH(_wethAddress);
    }

    //@title A functon for depositing ether
    // @notice User needs to send some token, when calling this function
    function deposit() external payable {
        if (msg.value == 0) revert ValueSentIsZeroError();

        UserDeposit memory userDeposit = userDeposits[msg.sender];
        if (userDeposit.balance == 0) userDeposit.lastDivident = totalDividends;
        userDeposit.balance += msg.value;
        userDeposit.reedemTime = block.timestamp + lockTime;

        _depositToLendingPool(msg.value);
        totalSupply += msg.value;
        userDeposits[msg.sender] = userDeposit;
        emit DepositEvent(msg.sender, msg.value, userDeposit.reedemTime);
    }

    //@title A functon for reedeming staked ether
    // @author Stefan Plazic
    // @notice User will need to pay a fee if he reedems before reedemTime
    // @dev Mechanism for keeping track about user dividends is done, by making user to pull their dividends, instead of calculating them for each user in deposit function
    function reedem() external returns (uint256) {
        _updateUserShare(msg.sender);
        UserDeposit memory userDeposit = userDeposits[msg.sender];
        if (userDeposit.balance == 0) revert NoTokensToReedemError(msg.sender);

        uint256 _totalSupply = totalSupply - userDeposit.balance;

        //if this is only user, don't take fee from him
        if (_totalSupply <= DUST) {
            _totalSupply = totalSupply;
            delete userDeposits[msg.sender];
            _removeFromLendingPool(msg.sender, _totalSupply);
            emit ReedemEvent(msg.sender, _totalSupply);
            totalSupply = 0;
            unclaimedDividends = 0;
            return _totalSupply;
        }

        uint256 userFee = feeStrategy.calculateAccountFee(
            userDeposit.reedemTime,
            lockTime,
            userDeposit.balance
        );

        uint256 userWithdraw = userDeposit.balance - userFee;
        //if user is reedeming before reedemTime -> take fee from his balance
        if (userFee > 0) {
            totalDividends += ((userFee * POINT_MULTIPLIER) /
                (_totalSupply - unclaimedDividends));
            unclaimedDividends += userFee;
        }

        totalSupply -= userWithdraw;

        delete userDeposits[msg.sender];

        _removeFromLendingPool(msg.sender, userWithdraw);
        emit ReedemEvent(msg.sender, userWithdraw);
        return userWithdraw;
    }

    //@title A functon for taking interest for owner
    // @author Stefan Plazic
    // @notice Only owner can call this function, if no interest error will be thrown
    // @dev if a balance of Atoken if greater then totalSuppy variable, then diference shall be widthrawn and converted to ether, before sending it to the owner
    function takeInterest() external onlyOwner {
        uint256 balance = iAToken.balanceOf(address(this));
        if (balance <= totalSupply) revert NoInterestToReedemError(msg.sender);
        uint256 withdrawAmount = balance - totalSupply;
        _removeFromLendingPool(msg.sender, withdrawAmount);
        emit OwnerInterestEvent(msg.sender, withdrawAmount);
    }

    function getLockTime() public view returns (uint256) {
        return lockTime;
    }

    function getTotalSupply() public view returns (uint256) {
        return totalSupply;
    }

    function setFeeStrategy(address _feeStrategyAddress) external onlyOwner {
        if (_feeStrategyAddress == address(0)) revert ZeroAddressError();
        feeStrategy = IFeeStrategy(_feeStrategyAddress);
    }

    //@title Caculate account fee for given account
    // @author Stefan Plazic
    // @dev This function calls FeeStrategy contract for calculating fee
    function calculateAccountFee(address account)
        public
        view
        returns (uint256)
    {
        UserDeposit memory userDeposit = userDeposits[account];
        return
            feeStrategy.calculateAccountFee(
                userDeposit.reedemTime,
                lockTime,
                userDeposit.balance
            );
    }

    function getUserDeposit(address account)
        external
        view
        returns (UserDeposit memory)
    {
        return userDeposits[account];
    }

    //@title Caculate user share of collected fees
    // @author Stefan Plazic
    function _getUserShareAmount(UserDeposit memory userDeposit)
        private
        view
        returns (uint256)
    {
        uint256 userDividendPoints = totalDividends - userDeposit.lastDivident;
        return (userDeposit.balance * userDividendPoints) / POINT_MULTIPLIER;
    }

    //@title Updates user balance with his share of unclaimed user fees
    // @author Stefan Plazic
    function _updateUserShare(address account) private {
        UserDeposit memory userDeposit = userDeposits[account];
        uint256 userShare = _getUserShareAmount(userDeposit);
        if (userShare > 0) {
            unclaimedDividends -= userShare;
            userDeposit.balance += userShare;
            userDeposit.lastDivident = totalDividends;
            userDeposits[account] = userDeposit;
        }
    }

    //@title Removes weth from avve contract
    // @author Stefan Plazic
    // @dev First weth is withdrawn to this contract, then converted to ether and sent to caller addressf
    function _removeFromLendingPool(address account, uint256 withdrawAmount)
        private
    {
        address poolAddress = _getPool();
        IPool(poolAddress).withdraw(
            address(weth),
            withdrawAmount,
            address(this)
        );
        weth.withdraw(withdrawAmount);
        (bool success, ) = account.call{value: withdrawAmount}("");
        if (!success) revert SendingEtherFailedError(account);
    }

    //@title Deposit ether to avve pool
    // @author Stefan Plazic
    function _depositToLendingPool(uint256 depositAmount) private {
        address poolAddress = _getPool();
        weth.deposit{value: depositAmount}();
        weth.approve(poolAddress, depositAmount);
        IPool(poolAddress).deposit(
            address(weth),
            depositAmount,
            address(this),
            0
        );
    }

    //@title Gets pool address, which can change during times
    // @author Stefan Plazic
    function _getPool() private view returns (address) {
        return poolAddressesProvider.getPool();
    }

    receive() external payable {}
}
