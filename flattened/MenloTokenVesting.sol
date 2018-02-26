pragma solidity ^0.4.18;

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

contract MenloTokenVesting is Ownable {
  using SafeMath for uint256;

  // Contract holds ERC20 MET tokens.
  ERC20Basic token;
  uint256 vestingAmount;

  // Important dates for vesting contract.
  uint256 public startTime;
  uint256 public cliffTime;
  uint256 public releaseTime;

  // Small caveat 1 month will be considered as 30 days and therefore
  // 1 year 360 days.
  uint256 public period;
  uint256 public numPeriods;

  // Mappings on how much is allocated and how much has been collected
  mapping (address => uint256) public allocations;
  mapping (address => uint256) public collections;

  // General allocated and collected variables.
  uint256 public allocated;
  uint256 public collected;
  bool public allocationFinished;

  event TokensWithdrawn(address indexed _holder, uint256 _amount);

  function MenloTokenVesting(
      address _token,
      uint256 _startTime,
      uint256 _cliffTime,
      uint256 _releaseTime,
      uint256 _period,
      uint256 _vestingAmount
  ) public {
    require(_token != 0x0);
    require(_startTime > getBlockTimestamp());
    require(_cliffTime >= _startTime);
    require(_releaseTime >= _cliffTime);
    require(_vestingAmount > 0);
    token = ERC20Basic(_token);
    vestingAmount = _vestingAmount;
    startTime = _startTime;
    cliffTime = _cliffTime;
    releaseTime = _releaseTime;
    period = _period;
    numPeriods = releaseTime.sub(startTime).div(period);
  }

  function allocateArray(
      address[] _holders,
      uint256[] _amounts
  ) public onlyOwner {
    require(_holders.length == _amounts.length);
    for (uint256 i = 0; i < _holders.length; i++) {
      allocate(_holders[i], _amounts[i]);
    }
  }

  function allocate(address _holder, uint256 _amount) public onlyOwner {
    require(!allocationFinished);
    require(_holder != 0x0);
    allocated = allocated.sub(allocations[_holder]).add(_amount);
    require(allocated <= token.balanceOf(address(this)));

    if (allocated == vestingAmount) {
      finishAllocation();
    }

    allocations[_holder] = _amount;
  }

  function finishAllocation() public onlyOwner {
    vestingAmount = allocated;
    allocationFinished = true;
  }

  function collect() public {
    require(getBlockTimestamp() >= cliffTime);
    uint256 balance = allocations[msg.sender];
    uint256 total = collections[msg.sender].add(balance);

    uint256 periodsPassed = getBlockTimestamp().sub(startTime).div(period);

    uint256 entitled = total.mul(periodsPassed).div(numPeriods);

    entitled = entitled.sub(collections[msg.sender]);

    if (entitled > balance) {
      entitled = balance;
    }

    allocations[msg.sender] = allocations[msg.sender].sub(entitled);
    collections[msg.sender] = collections[msg.sender].add(entitled);
    allocated = allocated.sub(entitled);
    collected = collected.add(entitled);

    require(token.transfer(msg.sender, entitled));

    TokensWithdrawn(msg.sender, entitled);
  }

  function getBlockTimestamp() internal view returns (uint256) {
    return block.timestamp;
  }

  event TokensClaimed(address indexed token, uint256 _amount);

  function claimTokens(address _token) public onlyOwner {
    if (_token == 0x0) {
      owner.transfer(this.balance);
      return;
    }

    ERC20Basic refundToken = ERC20Basic(_token);
    uint256 balance = refundToken.balanceOf(this);

    if (refundToken == token) {
      balance = balance.sub(allocated);
    }

    refundToken.transfer(owner, balance);
    TokensClaimed(_token, balance);
  }
}

contract ERC20Basic {
  uint256 public totalSupply;
  function balanceOf(address who) public constant returns (uint256);
  function transfer(address to, uint256 value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}
