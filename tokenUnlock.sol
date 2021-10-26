pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract tokenVesting is Ownable{
    using SafeMath for uint256;
    ERC20 _token;
    
    // bool public initialized = false;
    // uint256 public raisedAmount = 0;
    uint256 public totalWithdrawed = 0;
    // enum Round {seed, private_sale};
    mapping (address => Customer) public customers;
    struct Customer {
        address payable walletAddress;  // Customer wallet address
        uint256 totalTokens;            // total token of customer
        uint256 claimableTokens;        // amount of tokens that customer can claim
        uint256 claimedTokens;          // amount of claimed tokens of customer
    }
    
    TimeLock[] public timeLocks;
    struct TimeLock {
        uint256 datetime;               // unlock time
        uint256 unlockPercent;          // percent of token unlock
    }
    
    event CustomerAdded(address walletAddress, uint256 totalTokens);
    event CustomerUpdated(address walletAddress, uint256 totalTokens);
    event CustomerClaimed(address walletAddress, uint256 amountTokens, uint256 remainTokens);

    // address wallet;
    constructor(address token_address) public {
        _token = ERC20(address(token_address));
    }
    
    // require sender is in customer list 
    modifier customerExist() {
        require(customers[msg.sender].walletAddress != address(0), "Your wallet not found!");
        _;
    }
    
    modifier hasTimeLock() {
        require(timeLocks.length > 0, "Unlock schedule is unavailable!");
        _;
    }
    // get my token balance
    function myTokenBalance() public view returns(uint256) {
        return _token.balanceOf(msg.sender);
    }
    
    /**
    * set TGE timestamp
    * @dev set uint256 of TGE timestamp.
    * @param TGETimestamp timestamp of TGE
    */
    function setTimeLockByTGE(uint256 TGETimestamp) public onlyOwner {
        timeLocks.push(TimeLock(TGETimestamp, 5));
        
        uint256 dateAfterLock = TGETimestamp + 90 days;
        for (uint256 index = 0; index < 23; index++) {
            timeLocks.push(TimeLock(dateAfterLock + index * 30 days, 4));
        }
        timeLocks.push(TimeLock(dateAfterLock + 23 * 30 days, 3));
    }
    
    /**
    * get get claimable tokens 
    * @dev set uint256 of TGE timestamp.
    */
    function getClaimableTokens() public view customerExist returns (address myWallet, uint256 totalTokens, uint256 claimableTokens, uint256 claimedTokens) {
        uint256 claimableTokens = calculateClaimable(msg.sender);
        return(msg.sender, customers[msg.sender].totalTokens, claimableTokens, customers[msg.sender].claimedTokens);
    }
    
    /**
    * addCustomer
    * @dev Add a customer.
    * @param walletAddress customer's wallet address
    * @param totalToken customer's total token
    */
    function addCustomer(address payable walletAddress, uint256 totalToken) public onlyOwner {
        require(customers[walletAddress].totalTokens == 0, "This customer has added, please check again!");
        customers[walletAddress] = Customer(walletAddress, totalToken, 0, 0);
        emit CustomerAdded(walletAddress, totalToken);
    }
    
    /**
    * updateCustomer
    * @dev Update customer when he/she not claim token yet.
    * @param walletAddress customer's wallet address
    * @param totalToken customer's total token
    */
    function updateCustomer(address payable walletAddress, uint256 totalToken) public onlyOwner {
        require(customers[walletAddress].claimedTokens == 0 && customers[walletAddress].claimableTokens == 0, "Unable to update because this customer already has an unlocked amount of tokens!");
        customers[walletAddress] = Customer(walletAddress, totalToken, 0, 0);
        emit CustomerUpdated(walletAddress, totalToken);
    }
    
    /**
    * updateClaimableCustomers
    * @dev Update claimable token of all customers.
    */
    // function updateClaimableCustomers() public onlyOwner {
    //     uint256 unlockPercent = calculateUnlockPercent();
        
    //     for (uint256 index = 0; index < customers.length; index++) {
    //         unlockedTokens = customers[wallet].totalTokens * unlockPercent / 100;
    //         if (unlockedTokens) {
                
    //         }
    //     }
    //     uint256 claimableTokens = calculateClaimable(msg.sender);
    //     customers[msg.sender].claimableTokens = claimableTokens;
    //     uint256 remainTokens = customers[msg.sender].totalTokens.sub(customers[msg.sender].claimedTokens);
    // }
    
    /**
    * transferToken
    * @dev user claim token by locking schedule
    **/
    function transferToken(address recipient, uint256 amount) public onlyOwner {
        require(amount <= _token.balanceOf(address(this)), "There is not enough tokens in contract balance to make this transaction");
        _token.transfer(recipient, amount);
    }

    /**
    * claimToken
    * @dev user claim token by locking schedule
    **/
    function claimToken(uint256 amount) public customerExist hasTimeLock {
        uint256 claimableTokens = calculateClaimable(msg.sender);
        require(claimableTokens > 0 && claimableTokens >= amount, "Your claimable tokens are not enough!");
        require(amount <= _token.balanceOf(address(this)), "There is not enough tokens in contract balance to make this transaction");
        customers[msg.sender].claimableTokens = claimableTokens;
        _token.transfer(msg.sender, amount);
        customers[msg.sender].claimedTokens += amount;
        customers[msg.sender].claimableTokens -= amount;
        totalWithdrawed += amount;
        uint256 remainTokens = customers[msg.sender].totalTokens.sub(customers[msg.sender].claimedTokens);
        emit CustomerClaimed(msg.sender, amount, remainTokens);
    }

    /**
    * tokensAvailable
    * @dev returns the number of tokens allocated to this contract
    **/
    function tokensAvailable() public view returns (uint256) {
        return _token.balanceOf(address(this));
    }
    
    /**
    * calculateClaimable
    * @dev returns the number of claimable tokens
    **/
    function calculateClaimable(address wallet) private view hasTimeLock returns (uint256) {
        uint256 unlockedTokens = 0;
        uint256 unlockPercent = calculateUnlockPercent();
        unlockedTokens = customers[wallet].totalTokens * unlockPercent / 100;
        require(unlockedTokens <= customers[wallet].totalTokens);
        if (unlockedTokens == 0) {
            return customers[wallet].claimableTokens;
        }
        uint256 claimableTokens = unlockedTokens - customers[wallet].claimedTokens;
        return claimableTokens;
    }
    
    /**
    * calculateUnlockPercent
    * @dev returns the number of unlock percent tokens until now
    **/
    function calculateUnlockPercent() private view hasTimeLock returns (uint256) {
        uint256 unlockPercent = 0;
        for (uint256 index = 0; index < timeLocks.length; index++) {
            if (timeLocks[index].datetime > block.timestamp) break;
            unlockPercent += timeLocks[index].unlockPercent;
        }
        return unlockPercent;
    }
}