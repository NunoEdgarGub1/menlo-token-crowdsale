pragma solidity ^0.4.13;

contract Ownable {
  address public owner;


  event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  function Ownable() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }


  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param newOwner The address to transfer ownership to.
   */
  function transferOwnership(address newOwner) onlyOwner public {
    require(newOwner != address(0));
    OwnershipTransferred(owner, newOwner);
    owner = newOwner;
  }

}

contract MenloTokenPresale is Ownable {
  using SafeMath for uint256;

  // Token allocations
  mapping (address => uint256) public allocations;

  // Whitelisted investors
  mapping (address => bool) public whitelist;

  // manual early close flag
  bool public isFinalized = false;

  // cap for crowdsale in wei
  uint256 public cap;

  // The token being sold
  MenloToken public token;

  // start and end timestamps where contributions are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  /**
   * @dev Throws if called by any account other than the whitelister.
   */
  modifier onlyWhitelister() {
    require(msg.sender == whitelister);
    _;
  }

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  /**
   * event for token redemption logging
   * @param beneficiary who got the tokens
   * @param amount amount of tokens redeemed
   */
  event TokenRedeem(address indexed beneficiary, uint256 amount);

  // termination early or otherwise
  event Finalized();

  /**
   * event refund of excess ETH if purchase is above the cap
   * @param amount amount of ETH (in wei) refunded
   */
  event Refund(address indexed purchaser, address indexed beneficiary, uint256 amount);

  function MenloTokenPresale(
      address _token,
      uint256 _startTime,
      uint256 _endTime,
      uint256 _cap,
      address _wallet
  ) public {
    require(_startTime >= getBlockTimestamp());
    require(_endTime >= _startTime);
    require(_cap > 0);
    require(_cap <= MenloToken(_token).PRESALE_SUPPLY());
    require(_wallet != 0x0);
    require(_token != 0x0);

    token = MenloToken(_token);
    startTime = _startTime;
    endTime = _endTime;
    cap = _cap;
    wallet = _wallet;
  }

  // fallback function can be used to buy tokens
  function () public payable {
    buyTokens(msg.sender);
  }

  // 1 ETH = 6,750 MET
  function calculateBonusRate() public view returns (uint256) {
    uint256 bonusRate = 6750;

    return bonusRate;
  }

  /// @notice interface for founders to whitelist investors
  /// @param _addresses array of investors
  /// @param _status enable or disable
  function whitelistAddresses(address[] _addresses, bool _status) public onlyWhitelister {
    for (uint256 i = 0; i < _addresses.length; i++) {
        address investorAddress = _addresses[i];
        if (whitelist[investorAddress] == _status) {
          continue;
        }
        whitelist[investorAddress] = _status;
    }
   }

   function ethToTokens(uint256 ethAmount) internal view returns (uint256) {
    return ethAmount.mul(calculateBonusRate());
   }

   address public tokenTimelock;

   function setTokenTimeLock(address _tokenTimelock) public onlyOwner {
     tokenTimelock = _tokenTimelock;
   }

  address public whitelister;

   function setWhitelister(address _whitelister) public onlyOwner {
      whitelister = _whitelister;
   }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address beneficiary) public payable {
    require(whitelist[beneficiary]);
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;

    uint256 remainingToFund = cap.sub(weiRaised);
    if (weiAmount > remainingToFund) {
      weiAmount = remainingToFund;
    }
    uint256 weiToReturn = msg.value.sub(weiAmount);
    uint256 tokens = ethToTokens(weiAmount);

    token.unpause();
    weiRaised = weiRaised.add(weiAmount);

    forwardFunds(weiAmount);
    if (weiToReturn > 0) {
      msg.sender.transfer(weiToReturn);
      Refund(msg.sender, beneficiary, weiToReturn);
    }
    // send tokens to MenloTokenTimelock
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    token.transfer(tokenTimelock, tokens);
    MenloTokenTimelock(tokenTimelock).deposit(beneficiary, tokens);
    token.pause();

    if (weiRaised == cap) {
      checkFinalize();
    }
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 amount) internal {
    wallet.transfer(amount);
  }

  function checkFinalize() public {
    if (hasEnded()) {
      finalize();
    }
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal returns (bool) {
    checkFinalize();
    require(!isFinalized);
    bool withinPeriod = getBlockTimestamp() >= startTime && getBlockTimestamp() <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool contractHasTokens = token.balanceOf(this) > 0;
    return withinPeriod && nonZeroPurchase && contractHasTokens;
  }

  // @return true if crowdsale event has ended or cap reached
  function hasEnded() public constant returns (bool) {
    if (isFinalized) {
      return true;
    }
    bool capReached = weiRaised >= cap;
    bool passedEndTime = getBlockTimestamp() > endTime;
    return passedEndTime || capReached;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }

  function emergencyFinalize() public onlyOwner {
    finalize();
  }
  // @dev does not require that crowdsale `hasEnded()` to leave safegaurd
  // in place if ETH rises in price too much during crowdsale.
  // Allows team to close early if cap is exceeded in USD in this event.
  function finalize() internal {
    require(!isFinalized);
    Finalized();
    isFinalized = true;
    token.transferOwnership(owner);
  }

  // Allows the owner to take back the tokens that are assigned to the sale contract.
  event TokensRefund(uint256 _amount);
  function refund() external onlyOwner returns (bool) {
      require(hasEnded());
      uint256 tokens = token.balanceOf(address(this));

      if (tokens == 0) {
         return false;
      }

      require(token.transfer(owner, tokens));

      TokensRefund(tokens);

      return true;
   }

  function claimTokens(address _token) public onlyOwner {
    require(hasEnded());
    if (_token == 0x0) {
        owner.transfer(this.balance);
        return;
    }

    ERC20Basic refundToken = ERC20Basic(_token);
    uint256 balance = refundToken.balanceOf(this);
    refundToken.transfer(owner, balance);
    TokensRefund(balance);
  }
}

contract MenloTokenSale is Ownable {
  using SafeMath for uint256;

  // Token allocations
  mapping (address => uint256) public allocations;

  // Whitelisted investors
  mapping (address => bool) public whitelist;

  // manual early close flag
  bool public isFinalized = false;

  // cap for crowdsale in wei
  uint256 public cap;

  // The token being sold
  MenloToken public token;

  // start and end timestamps where contributions are allowed (both inclusive)
  uint256 public startTime;
  uint256 public endTime;

  // address where funds are collected
  address public wallet;

  // amount of raised money in wei
  uint256 public weiRaised;

  /**
   * @dev Throws if called by any account other than the whitelister.
   */
  modifier onlyWhitelister() {
    require(msg.sender == whitelister);
    _;
  }

  // Timestamps for the bonus periods, set in the constructor
  uint256 private HOUR1;
  uint256 private WEEK1;
  uint256 private WEEK2;
  uint256 private WEEK3;
  uint256 private WEEK4;
  uint256 private WEEK5;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

  /**
   * event for token redemption logging
   * @param beneficiary who got the tokens
   * @param amount amount of tokens redeemed
   */
  event TokenRedeem(address indexed beneficiary, uint256 amount);

  // termination early or otherwise
  event Finalized();

  /**
   * event refund of excess ETH if purchase is above the cap
   * @param amount amount of ETH (in wei) refunded
   */
  event Refund(address indexed purchaser, address indexed beneficiary, uint256 amount);

  function MenloTokenSale(
      address _token,
      uint256 _startTime,
      uint256 _endTime,
      uint256 _cap,
      address _wallet
  ) public {
    require(_startTime >= getBlockTimestamp());
    require(_endTime >= _startTime);
    require(_cap > 0);
    require(_cap <= MenloToken(_token).PUBLICSALE_SUPPLY());
    require(_wallet != 0x0);
    require(_token != 0x0);

    token = MenloToken(_token);
    startTime = _startTime;
    endTime = _endTime;
    cap = _cap;
    wallet = _wallet;
    HOUR1 = startTime + 1 hours;
    WEEK1 = HOUR1 + 1 weeks;
    WEEK2 = WEEK1 + 1 weeks;
    WEEK3 = WEEK2 + 1 weeks;
    WEEK4 = WEEK3 + 1 weeks;
    WEEK5 = WEEK4 + 1 years;
  }

  // fallback function can be used to buy tokens
  function () public payable {
    buyTokens(msg.sender);
  }

  // Hour 1: 1 ETH = 6,500 MET (30% Bonus)
  // Week 1: 1 ETH = 6,000 MET (20% Bonus)
  // Week 2: 1 ETH = 5,750 MET (15% Bonus)
  // Week 3: 1 ETH = 5,500 MET (10% Bonus)
  // Week 4: 1 ETH = 5,250 MET (5% Bonus)
  function calculateBonusRate() public view returns (uint256) {
    uint256 bonusRate = 5000;

    uint256 currentTime = getBlockTimestamp();
    if (currentTime > startTime && currentTime <= HOUR1) {
      bonusRate =  6500;
    } else if (currentTime <= WEEK1) {
      bonusRate =  6000; // after 1 hour
    } else if (currentTime <= WEEK2) {
      bonusRate =  5750; // after 1 week
    } else if (currentTime <= WEEK3) {
      bonusRate =  5500; // after 2 weeks
    } else if (currentTime <= WEEK4) {
      bonusRate =  5250; // after 3 weeks
    } else if (currentTime <= WEEK5) {
      bonusRate = 5000; // after 4 weeks
    }
    return bonusRate;
  }

  /// @notice interface for founders to whitelist investors
  /// @param _addresses array of investors
  /// @param _status enable or disable
  function whitelistAddresses(address[] _addresses, bool _status) public onlyWhitelister {
    for (uint256 i = 0; i < _addresses.length; i++) {
        address investorAddress = _addresses[i];
        if (whitelist[investorAddress] == _status) {
          continue;
        }
        whitelist[investorAddress] = _status;
    }
   }

   function ethToTokens(uint256 ethAmount) internal view returns (uint256) {
    return ethAmount.mul(calculateBonusRate());
   }

   address public whitelister;

    function setWhitelister(address _whitelister) public onlyOwner {
       whitelister = _whitelister;
    }

  // low level token purchase function
  // caution: tokens must be redeemed by beneficiary address
  function buyTokens(address beneficiary) public payable {
    require(whitelist[beneficiary]);
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;

    uint256 remainingToFund = cap.sub(weiRaised);
    if (weiAmount > remainingToFund) {
      weiAmount = remainingToFund;
    }
    uint256 weiToReturn = msg.value.sub(weiAmount);
    uint256 tokens = ethToTokens(weiAmount);

    token.unpause();
    weiRaised = weiRaised.add(weiAmount);

    forwardFunds(weiAmount);
    if (weiToReturn > 0) {
      msg.sender.transfer(weiToReturn);
      Refund(msg.sender, beneficiary, weiToReturn);
    }
    // send tokens to purchaser
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    token.transfer(beneficiary, tokens);
    token.pause();
    TokenRedeem(beneficiary, tokens);
    if (weiRaised == cap) {
      checkFinalize();
    }
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds(uint256 amount) internal {
    wallet.transfer(amount);
  }

  function checkFinalize() public {
    if (hasEnded()) {
      finalize();
    }
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal returns (bool) {
    checkFinalize();
    require(!isFinalized);
    bool withinPeriod = getBlockTimestamp() >= startTime && getBlockTimestamp() <= endTime;
    bool nonZeroPurchase = msg.value != 0;
    bool contractHasTokens = token.balanceOf(this) > 0;
    return withinPeriod && nonZeroPurchase && contractHasTokens;
  }

  // @return true if crowdsale event has ended or cap reached
  function hasEnded() public constant returns (bool) {
    if (isFinalized) {
      return true;
    }
    bool capReached = weiRaised >= cap;
    bool passedEndTime = getBlockTimestamp() > endTime;
    return passedEndTime || capReached;
  }

  function getBlockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }

  function emergencyFinalize() public onlyOwner {
    finalize();
  }
  // @dev does not require that crowdsale `hasEnded()` to leave safegaurd
  // in place if ETH rises in price too much during crowdsale.
  // Allows team to close early if cap is exceeded in USD in this event.
  function finalize() internal {
    require(!isFinalized);
    Finalized();
    isFinalized = true;
    token.transferOwnership(owner);
  }

  // Allows the owner to take back the tokens that are assigned to the sale contract.
  event TokensRefund(uint256 _amount);
  function refund() external onlyOwner returns (bool) {
      require(hasEnded());
      uint256 tokens = token.balanceOf(address(this));

      if (tokens == 0) {
         return false;
      }

      require(token.transfer(owner, tokens));

      TokensRefund(tokens);

      return true;
   }

  function claimTokens(address _token) public onlyOwner {
    require(hasEnded());
    if (_token == 0x0) {
        owner.transfer(this.balance);
        return;
    }

    ERC20Basic refundToken = ERC20Basic(_token);
    uint256 balance = refundToken.balanceOf(this);
    refundToken.transfer(owner, balance);
    TokensRefund(balance);
  }
}

contract Pausable is Ownable {
  event Pause();
  event Unpause();

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused);
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused);
    _;
  }

  /**
   * @dev called by the owner to pause, triggers stopped state
   */
  function pause() onlyOwner whenNotPaused public {
    paused = true;
    Pause();
  }

  /**
   * @dev called by the owner to unpause, returns to normal state
   */
  function unpause() onlyOwner whenPaused public {
    paused = false;
    Unpause();
  }
}

library SafeERC20 {
  function safeTransfer(ERC20Basic token, address to, uint256 value) internal {
    assert(token.transfer(to, value));
  }

  function safeTransferFrom(ERC20 token, address from, address to, uint256 value) internal {
    assert(token.transferFrom(from, to, value));
  }

  function safeApprove(ERC20 token, address spender, uint256 value) internal {
    assert(token.approve(spender, value));
  }
}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}

contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) public constant returns (uint256);
  function transferFrom(address from, address to, uint256 value) public returns (bool);
  function approve(address spender, uint256 value) public returns (bool);
  event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BasicToken is ERC20Basic {
  using SafeMath for uint256;

  mapping(address => uint256) balances;

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of.
  * @return An uint256 representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) public constant returns (uint256 balance) {
    return balances[_owner];
  }

}

contract StandardToken is ERC20, BasicToken {

  mapping (address => mapping (address => uint256)) allowed;


  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint256 the amount of tokens to be transferred
   */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
    require(_to != address(0));

    uint256 _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // require (_value <= _allowance);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
   *
   * Beware that changing an allowance with this method brings the risk that someone may use both the old
   * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
   * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
   * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint256 _value) public returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * @dev Function to check the amount of tokens that an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint256 specifying the amount of tokens still available for the spender.
   */
  function allowance(address _owner, address _spender) public constant returns (uint256 remaining) {
    return allowed[_owner][_spender];
  }

  /**
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   */
  function increaseApproval (address _spender, uint _addedValue)
    returns (bool success) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  function decreaseApproval (address _spender, uint _subtractedValue)
    returns (bool success) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

}

contract BurnableToken is StandardToken {

    event Burn(address indexed burner, uint256 value);

    /**
     * @dev Burns a specific amount of tokens.
     * @param _value The amount of token to be burned.
     */
    function burn(uint256 _value) public {
        require(_value > 0);

        address burner = msg.sender;
        balances[burner] = balances[burner].sub(_value);
        totalSupply = totalSupply.sub(_value);
        Burn(burner, _value);
    }
}

contract PausableToken is StandardToken, Pausable {

  function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    return super.approve(_spender, _value);
  }

  function increaseApproval(address _spender, uint _addedValue) public whenNotPaused returns (bool success) {
    return super.increaseApproval(_spender, _addedValue);
  }

  function decreaseApproval(address _spender, uint _subtractedValue) public whenNotPaused returns (bool success) {
    return super.decreaseApproval(_spender, _subtractedValue);
  }
}

contract MenloToken is PausableToken, BurnableToken {

  // Token properties.
  string public constant name = 'MenloToken';
  string public constant symbol = 'MET';
  // ERC20 compliant types
  // (see https://blog.zeppelin.solutions/tierion-network-token-audit-163850fd1787)
  uint8 public constant decimals = 18;
  uint256 private constant token_factor = 10**uint256(decimals);
  // 1 billion MET tokens in units divisible up to 18 decimals.
  uint256 public constant INITIAL_SUPPLY = 1000 * (10**6) * token_factor;

  uint256 public constant PRESALE_SUPPLY = 30000000 * token_factor;
  uint256 public constant PUBLICSALE_SUPPLY = 270000000 * token_factor;
  uint256 public constant GROWTH_SUPPLY = 300000000 * token_factor;
  uint256 public constant TEAM_SUPPLY = 200000000 * token_factor;
  uint256 public constant ADVISOR_SUPPLY = 100000000 * token_factor;
  uint256 public constant PARTNER_SUPPLY = 100000000 * token_factor;

  function MenloToken() public {
    require(INITIAL_SUPPLY > 0);
    require((PRESALE_SUPPLY + PUBLICSALE_SUPPLY + GROWTH_SUPPLY + TEAM_SUPPLY + ADVISOR_SUPPLY + PARTNER_SUPPLY) == INITIAL_SUPPLY);
    totalSupply = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    Transfer(0x0, msg.sender, INITIAL_SUPPLY);
  }

  address private crowdsale;

  function isCrowdsaleAddressSet() public constant returns (bool) {
    return (address(crowdsale) != address(0));
  }

  modifier crowdsaleNotInitialized() {
    require(!isCrowdsaleAddressSet());
    _;
  }

  function initializeCrowdsale(address _crowdsale) public onlyOwner crowdsaleNotInitialized {
    transfer(_crowdsale, PUBLICSALE_SUPPLY);
    crowdsale = _crowdsale;
    pause();
    transferOwnership(_crowdsale);
  }

  address private presale;

  function isPresaleAddressSet() public constant returns (bool) {
    return (address(presale) != address(0));
  }

  modifier presaleNotInitialized() {
    require(!isPresaleAddressSet());
    _;
  }

  function initializePresale(address _presale) public onlyOwner presaleNotInitialized {
    transfer(_presale, PRESALE_SUPPLY);
    presale = _presale;
    pause();
    transferOwnership(_presale);
  }

  function getBlockTimestamp() internal constant returns (uint256) {
    return block.timestamp;
  }

  // Don't accept calls to the contract address; must call a method.
  function () public {
    revert();
  }

  function claimTokens(address _token) public onlyOwner {
        if (_token == 0x0) {
            owner.transfer(this.balance);
            return;
        }

        ERC20Basic token = ERC20Basic(_token);
        uint256 balance = token.balanceOf(this);
        token.transfer(owner, balance);
    }

}

library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract MenloTokenTimelock {
  using SafeERC20 for ERC20Basic;

  // ERC20 basic token contract being held
  ERC20Basic public token;

  // MENLO-NOTE!
  mapping (address => uint) public balance;

  // timestamp when token release is enabled
  uint256 public releaseTime;

  // MENLO-NOTE!
  address public presale;

  modifier onlyPresale() {
    require(msg.sender == presale);
    _;
  }

  function MenloTokenTimelock(ERC20Basic _token, address _presale, uint256 _releaseTime) public {
    require(_releaseTime > now);
    token = _token;
    presale = _presale;
    releaseTime = _releaseTime;
  }

  // MENLO-NOTE!
  function deposit(address _beneficiary, uint256 _amount) public onlyPresale {
    balance[_beneficiary] += _amount;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    require(now >= releaseTime);

    uint256 amount = token.balanceOf(this);
    require(amount > 0);
    // MENLO-NOTE!
    require(balance[msg.sender] > 0);
    require(amount >= balance[msg.sender]);
    token.transfer(msg.sender, balance[msg.sender]);
  }
}

