// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IFeeStrategy.sol";
import "./interfaces/IWETH.sol";
import "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import "@aave/core-v3/contracts/interfaces/IPool.sol";
import "@aave/core-v3/contracts/interfaces/IAToken.sol";

contract StrongHand is Ownable {
    uint256 private lockTime;
    uint256 private totalSupply;
    uint256 private totalDividends;
    uint256 private unclaimedDividends;
    uint256 private constant POINT_MULTIPLIER = 10e18;

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

    event DepositEvent(
        address indexed sender,
        uint256 amount,
        uint256 reedemTime
    );
    event ReedemEvent(address indexed reedemer, uint256 amount);
    event OwnerInterestEvent(address indexed owner, uint256 amount);

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

    function reedem() external returns (uint256) {
        _updateUserShare(msg.sender);
        UserDeposit memory userDeposit = userDeposits[msg.sender];
        uint256 _totalSupply = totalSupply - userDeposit.balance;

        if (userDeposit.balance == 0) revert NoTokensToReedemError(msg.sender);

        if (_totalSupply == 0) {
            totalSupply = _totalSupply;
            delete userDeposits[msg.sender];
            _removeFromLendingPool(msg.sender, userDeposit.balance);
            emit ReedemEvent(msg.sender, userDeposit.balance);
            return userDeposit.balance;
        }

        uint256 userFee = feeStrategy.calculateAccountFee(
            userDeposit.reedemTime,
            lockTime,
            userDeposit.balance
        );

        uint256 userWithdraw = userDeposit.balance - userFee;

        if (userFee > 0) {
            totalDividends += ((userFee * POINT_MULTIPLIER) / _totalSupply);
            unclaimedDividends += userFee;
        }

        totalSupply -= userWithdraw;

        delete userDeposits[msg.sender];

        _removeFromLendingPool(msg.sender, userWithdraw);
        emit ReedemEvent(msg.sender, userWithdraw);
        return userWithdraw;
    }

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

    function _getUserShareAmount(UserDeposit memory userDeposit)
        private
        view
        returns (uint256)
    {
        uint256 userDividendPoints = totalDividends - userDeposit.lastDivident;
        return (userDeposit.balance * userDividendPoints) / POINT_MULTIPLIER;
    }

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

    function _getPool() private view returns (address) {
        return poolAddressesProvider.getPool();
    }

    receive() external payable {}
}
