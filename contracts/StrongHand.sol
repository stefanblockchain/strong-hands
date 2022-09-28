// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ILendingPool.sol";

contract StrongHand is Ownable {
    uint256 private lockTime;
    uint256 private totalSupply;
    uint256 private totalDividends;
    uint256 private constant POINT_MULTIPLIER = 10 ^ 18;

    ILendingPool private immutable lendingPool;
    IWETH private immutable weith;
    IERC20 private immutable iAToken;

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

    constructor(
        uint256 _lockTime,
        address _lendingPoolAddress,
        address _weithAddress,
        address _iATokenAddress
    ) {
        lockTime = _lockTime;
        lendingPool = ILendingPool(_lendingPoolAddress);
        weith = IWETH(_weithAddress);
        iAToken = IERC20(_iATokenAddress);
    }

    function deposit() external payable {
        require(msg.value > 0, "Balance must be greater then 0");

        UserDeposit memory userDeposit = userDeposits[msg.sender];
        userDeposit.balance += msg.value;
        userDeposit.reedemTime = block.timestamp + lockTime;
        totalSupply += msg.value;
        weith.deposit{value: msg.value}();
        lendingPool.deposit(address(weith), msg.value, address(this), 0);
        emit DepositEvent(msg.sender, msg.value, userDeposit.reedemTime);
    }

    function reedem() external {
        UserDeposit memory userDeposit = userDeposits[msg.sender];
        require(userDeposit.balance > 0, "No tokens to reedem");
        //check if user can reedem with out fees -> reedem everyting
        
        //else -> calculate how much fee he gets
        // -> subtruct fee and update totalDividends
        // -> then send ether to user
        emit ReedemEvent(msg.sender, userDeposits[msg.sender].balance);
    }

    function takeInterest() external onlyOwner {
        uint256 balance = iAToken.balanceOf(address(this));
        require(balance > totalSupply, "No tokens to reedem");

        // iAToken.burn(address(this), address(this), balance, 0);
        weith.withdraw(balance);
        (bool sent, ) = msg.sender.call{value: balance}("");
        require(sent, "Sending ether failed");
        emit OwnerInterestEvent(msg.sender, balance);
    }

    function getLockTime() public view returns (uint256) {
        return lockTime;
    }

    function getUserRemainingTime(address _account)
        public
        view
        returns (uint256)
    {
        require(
            userDeposits[_account].reedemTime > 0,
            "User not deposited anything"
        );
        return block.timestamp - userDeposits[_account].reedemTime;
    }

    function isSafeToWithdraw(address _account) public view returns (bool) {
        return userDeposits[_account].reedemTime < block.timestamp;
    }
}
