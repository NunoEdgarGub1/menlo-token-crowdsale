pragma solidity ^0.4.23;

import 'zeppelin-solidity/contracts/token/ERC20/PausableToken.sol';
import 'zeppelin-solidity/contracts/token/ERC20/BurnableToken.sol';
import 'zeppelin-solidity/contracts/token/ERC20/ERC20Basic.sol';

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

  address private presale;
  address private crowdsale;

  modifier presaleNotInitialized() {
    require(!isPresaleAddressSet());
    _;
  }

  modifier crowdsaleNotInitialized() {
    require(!isCrowdsaleAddressSet());
    _;
  }

  constructor() public {
    require(INITIAL_SUPPLY > 0);
    require((PRESALE_SUPPLY + PUBLICSALE_SUPPLY + GROWTH_SUPPLY + TEAM_SUPPLY + ADVISOR_SUPPLY + PARTNER_SUPPLY) == INITIAL_SUPPLY);
    totalSupply_ = INITIAL_SUPPLY;
    balances[msg.sender] = INITIAL_SUPPLY;
    emit Transfer(0x0, msg.sender, INITIAL_SUPPLY);
  }

  function initializeCrowdsale(address _crowdsale) public onlyOwner crowdsaleNotInitialized {
    transfer(_crowdsale, PUBLICSALE_SUPPLY);
    crowdsale = _crowdsale;
    pause();
    transferOwnership(_crowdsale);
  }

  function initializePresale(address _presale) public onlyOwner presaleNotInitialized {
    transfer(_presale, PRESALE_SUPPLY);
    presale = _presale;
    pause();
    transferOwnership(_presale);
  }

  function claimTokens(ERC20Basic _token) public onlyOwner {
    if (address(_token) == 0x0) {
      owner.transfer(address(this).balance);
      return;
    }

    _token.transfer(owner, _token.balanceOf(this));
  }

  function isCrowdsaleAddressSet() public constant returns (bool) {
    return (address(crowdsale) != address(0));
  }

  function isPresaleAddressSet() public constant returns (bool) {
    return (address(presale) != address(0));
  }

  function getBlockTimestamp() internal constant returns (uint256) {
    return block.timestamp;
  }
}
