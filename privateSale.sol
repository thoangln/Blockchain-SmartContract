pragma solidity >=0.7.0 <0.9.0;

interface IKRC20 {
    function decimals() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract privateSale {
    using SafeMath for uint256;
    IKRC20 _token;

    uint256 public constant RATE = 10000; // Number of tokens per Ether
    uint256 public constant CAP = 7000; // Cap in Ether
    uint256 public constant START = 1634804584; // Thursday, October 21, 2021 8:23:04 AM
    uint256 public constant DAYS = 30; // 30 Day
    
    uint256 public initialTokens; // Initial number of tokens available
    bool public initialized = false;
    uint256 public raisedAmount = 0;
    // Payable address can receive Ether
    address payable public owner;

    // define price and amount token for this round.

    // address payable wallet;
    uint256 public price;
    // address tracker_0x_address = 0x7EF2e0048f5bAeDe046f6BF797943daF4ED8CB47;
    constructor(address token_address, uint256 _price) public payable{
        owner = payable(msg.sender);
        price = _price;
        _token = IKRC20(address(token_address));
        initialTokens = _token.balanceOf(owner);
    }
    
    function myTokenBalance() public view returns(uint256) {
        return _token.balanceOf(msg.sender);
    }

    /**
    * ownerOnly
    * @dev Throws an error if called by any account other than the owner.
    */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
    * transferOwnership
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address payable newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

    /**
    * BoughtTokens
    * @dev Log tokens bought onto the blockchain
    */
    event BoughtTokens(address indexed to, uint256 value);
    
    /**
    * whenSaleIsActive
    * @dev ensures that the contract is still active
    **/
    modifier whenSaleIsActive() {
        // Check if sale is active
        assert(isActive());
        _;
    }
    
    /**
    * initialize
    * @dev Initialize the contract
    **/
    function initialize() public onlyOwner {
        require(initialized == false); // Can only be initialized once
        require(tokensAvailable() == initialTokens); // Must have enough tokens allocated
        initialized = true;
    }

    /**
    * isActive
    * @dev Determins if the contract is still active
    **/
    function isActive() public view returns (bool) {
        return (
            initialized == true &&
            block.timestamp >= START && // Must be after the START date
            block.timestamp <= START.add(DAYS * 1 days) && // Must be before the end date
            goalReached() == false // Goal must not already be reached
        );
    }

    /**
    * goalReached
    * @dev Function to determin is goal has been reached
    **/
    function goalReached() public view returns (bool) {
        return (raisedAmount >= CAP * 1 ether);
    }

    /*
        Which function is called, fallback() or receive()?

            send Ether
                |
            msg.data is empty?
                / \
                yes  no
                /     \
    receive() exists?  fallback()
            /   \
            yes   no
            /      \
        receive()   fallback()
    */
    /**
    * @dev Fallback function if ether is sent to address insted of buyTokens function
    **/
    receive() external payable {
        buyTokens();
    }

    /**
    * buyTokens
    * @dev function that sells available tokens
    **/
    function buyTokens() public payable {
        assert(isActive());
        uint256 weiAmount = msg.value / (10 ** 18); // Calculate tokens to sell
        uint256 tokens = weiAmount.mul(RATE);
        
        emit BoughtTokens(msg.sender, tokens); // log event onto the blockchain
        raisedAmount = raisedAmount.add(msg.value); // Increment raised amount
        _token.transferFrom(owner, msg.sender, tokens); // Send tokens to buyer
        
        owner.transfer(msg.value);// Send money to owner
    }

    /**
    * tokensAvailable
    * @dev returns the number of tokens allocated to this contract
    **/
    function tokensAvailable() public returns (uint256) {
        return _token.balanceOf(owner);
    }

    /**
    * destroy
    * @notice Terminate contract and refund to owner
    **/
    function destroy() onlyOwner public {
        // Transfer tokens back to owner
        uint256 balance = _token.balanceOf(owner);
        assert(balance > 0);
        _token.transfer(owner, balance);
        // There should be no ether in the contract but just in case
        selfdestruct(owner);
    }

    // function getResult() public view returns (uint256) {
    //     IKRC20 _token = IKRC20(address(token));
    //     uint256 balance = _token.balanceOf(msg.sender);
    //     uint256 decimals = _token.decimals();
    //     // uint256 balance = _token.totalSupply();
    //     return balance;
    // }

    
    // people send KAI
    // save address, amount

    // send token by metrics to people sent
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
     * mul 
     * @dev Safe math multiply function
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
    /**
    * add
    * @dev Safe math addition function
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}