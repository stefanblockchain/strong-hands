// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/IFeeStrategy.sol";

contract StrongHand is Ownable {
    uint256 private lockTime;
    uint256 private totalSupply;
    uint256 private totalDividends;
    uint256 private unclaimedDividends;
    uint256 private constant POINT_MULTIPLIER = 10 ^ 18;

    ILendingPool private immutable lendingPool;
    IWETH private immutable weith;
    IERC20 private immutable iAToken;
    IFeeStrategy private feeStrategy;

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
    error SendingEtherFailedError();
    error ZeroAddressError();

    constructor(
        uint256 _lockTime,
        address _lendingPoolAddress,
        address _weithAddress,
        address _iATokenAddress,
        address _feeStrategyAddress
    ) {
        lockTime = _lockTime;
        lendingPool = ILendingPool(_lendingPoolAddress);
        weith = IWETH(_weithAddress);
        iAToken = IERC20(_iATokenAddress);
        feeStrategy = IFeeStrategy(_feeStrategyAddress);
    }

    function deposit() external payable {
        if (msg.value == 0) revert ValueSentIsZeroError();

        UserDeposit memory userDeposit = userDeposits[msg.sender];
        userDeposit.balance += msg.value;
        userDeposit.reedemTime = block.timestamp + lockTime;
        _depositToLendingPool(msg.value);
        totalSupply += msg.value;
        userDeposits[msg.sender] = userDeposit;
        emit DepositEvent(msg.sender, msg.value, userDeposit.reedemTime);
    }

    function reedem() external {
        UserDeposit memory userDeposit = userDeposits[msg.sender];
        if (userDeposit.balance == 0) revert NoTokensToReedemError(msg.sender);
        _updateUserShare(msg.sender);
        uint256 userFee = feeStrategy.calculateAccountFee(
            userDeposit.reedemTime,
            lockTime,
            userDeposit.balance
        );
        uint256 userWithdraw = userDeposit.balance - userFee;
        if (userFee > 0) {
            totalDividends += ((userFee * POINT_MULTIPLIER) / totalSupply);
            unclaimedDividends += userFee;
        }
        totalSupply -= userWithdraw;
        delete userDeposits[msg.sender];
        _removeFromLendingPool(msg.sender, userWithdraw);
        emit ReedemEvent(msg.sender, userDeposits[msg.sender].balance);
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

    function _getUserShareAmount(address account)
        private
        view
        returns (uint256)
    {
        UserDeposit memory userDeposit = userDeposits[account];
        uint256 userDividendPoints = totalDividends - userDeposit.lastDivident;
        return (userDeposit.balance * userDividendPoints) / POINT_MULTIPLIER;
    }

    function _updateUserShare(address account) private {
        uint256 userShare = _getUserShareAmount(account);
        if (userShare > 0) {
            UserDeposit memory userDeposit = userDeposits[account];
            unclaimedDividends -= userShare;
            userDeposit.balance += userShare;
            userDeposit.lastDivident = totalDividends;
            userDeposits[account] = userDeposit;
        }
    }

    function _removeFromLendingPool(address account, uint256 withdrawAmount)
        private
    {
        lendingPool.withdraw(address(weith), withdrawAmount, address(this));
        weith.withdraw(withdrawAmount);
        (bool sent, ) = account.call{value: withdrawAmount}("");
        if (!sent) revert SendingEtherFailedError();
    }

    function _depositToLendingPool(uint256 depositAmount) private {
        weith.deposit{value: depositAmount}();
        lendingPool.deposit(address(weith), depositAmount, address(this), 0);
    }
}
