pragma solidity ^0.4.18;

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
