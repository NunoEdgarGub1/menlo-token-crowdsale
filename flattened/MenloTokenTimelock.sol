pragma solidity ^0.4.18;

contract MenloTokenTimelock {
  using SafeERC20 for ERC20Basic;

  // ERC20 basic token contract being held
  ERC20Basic public token;

  mapping (address => uint) public balance;

  // timestamp when token release is enabled
  uint256 public releaseTime;

  function MenloTokenTimelock(ERC20Basic _token, uint256 _releaseTime) public {
    require(_releaseTime > now);
    token = _token;
    releaseTime = _releaseTime;
  }
  // TODO: callable only by contract
  function deposit(address _beneficiary, uint256 _amount) public {
    balance[_beneficiary] += _amount;
  }

  /**
   * @notice Transfers tokens held by timelock to beneficiary.
   */
  function release() public {
    require(now >= releaseTime);

    uint256 amount = token.balanceOf(this);
    require(amount > 0);
    require(balance[msg.sender] > 0);
    require(amount >= balance[msg.sender]);
    // release each presale participants tokens
    token.transfer(msg.sender, balance[msg.sender]);
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
