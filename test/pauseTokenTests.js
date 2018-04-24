'use strict';
let TokenSale = artifacts.require('./helpers/MenloTokenSaleMock.sol');
let METToken = artifacts.require('./helpers/MenloTokenMock.sol');

const BigNumber = require("bignumber.js");
const assertFail = require("./helpers/assertFail");

import { latestTime, duration } from './helpers/latestTime';

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()

const expect = require('chai').expect

const DECIMALS = 18;

contract('metTokenPause', async function([miner, owner, investor, investor2, wallet, whitelister]) {
  let tokenSaleDeployed;
  let tokenDeployed;
  let startTime, endTime;

  beforeEach(async function () {
    tokenDeployed = await METToken.new();
    startTime = latestTime() + duration.seconds(1);
    endTime = startTime + duration.weeks(6);
    const cap = web3.toWei(1, 'ether');
    tokenSaleDeployed = await TokenSale.new(tokenDeployed.address, startTime, endTime, cap, wallet);
    await tokenSaleDeployed.setBlockTimestamp(startTime + 1);
    await tokenSaleDeployed.setWhitelister(whitelister);
    await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);
  });

  it('tokens should be paused once they are sold',
    async function () {
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    const value = web3.toWei(0.1, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 650 * 10 ** DECIMALS, 'balanceOf is 650 for investor who just bought tokens');

    await assertFail(async () => { await tokenDeployed.transfer(investor2, 10, { from: investor }) });
  });

  it('crowdsale should finalize when cap is reached',
    async function () {
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    const value = web3.toWei(1, 'ether');
    const { logs } = await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6500 * 10 ** DECIMALS, 'balanceOf is 6500 for investor who just bought tokens');

    const event = logs.find(e => e.event === 'Finalized');
    expect(event).to.exist;
  });

  it('crowdsale should finalize when time runs out',
    async function () {
    let isFinalized = await tokenSaleDeployed.isFinalized();
    assert.isFalse(isFinalized, "isFinalized should be false");

    await tokenSaleDeployed.setBlockTimestamp(endTime + 1);
    await tokenSaleDeployed.checkFinalize();

    isFinalized = await tokenSaleDeployed.isFinalized();
    assert.isTrue(isFinalized, "isFinalized should be true");
  });

  it('tokens should be unpaused once crowdsale is finalized (hit cap)',
    async function () {
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    // Buy half the tokens in the cap
    const value = web3.toWei(0.5, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 3250 * 10 ** DECIMALS, 'balanceOf is 3250 for investor who just bought tokens');
    await assertFail(async () => { await tokenDeployed.transfer(investor2, 10, { from: investor }) });

    // Buy the remaining half
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
    balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6500 * 10 ** DECIMALS, 'balanceOf is 6500 for investor who just bought tokens');
    await tokenSaleDeployed.setBlockTimestamp(endTime);
    await tokenDeployed.setBlockTimestamp(endTime);
    await tokenDeployed.unpause();
    // Token should be unpaused, can now transfer
    await tokenDeployed.transfer(investor2, 3250 * 10 ** DECIMALS, { from: investor });
    balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 3250 * 10 ** DECIMALS, 'balanceOf is 3250 for investor after transferring tokens');
    balance = await tokenDeployed.balanceOf(investor2);
    assert.equal(balance.toNumber(), 3250 * 10 ** DECIMALS, 'balanceOf is 3250 for investor2 who just received tokens');
  });

  it('tokens should be unpaused once crowdsale is finalized (time ran out)',
    async function () {
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    // Buy half the tokens in the cap
    const value = web3.toWei(0.5, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 3250 * 10 ** DECIMALS, 'balanceOf is 3250 for investor who just bought tokens');
    await assertFail(async () => { await tokenDeployed.transfer(investor2, 10, { from: investor }) });

    await tokenSaleDeployed.setBlockTimestamp(endTime + duration.days(7));
    await tokenDeployed.setBlockTimestamp(endTime + duration.days(7));

    await tokenSaleDeployed.checkFinalize();
    await tokenDeployed.unpause();
    let isFinalized = await tokenSaleDeployed.isFinalized();
    assert.isTrue(isFinalized, "isFinalized should be true");

    // Token should be unpaused, can now transfer
    await tokenDeployed.transfer(investor2, 3250 * 10 ** DECIMALS, { from: investor });
    balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 0, 'balanceOf is 0 for investor who just transferred tokens');
    balance = await tokenDeployed.balanceOf(investor2);
    assert.equal(balance.toNumber(), 3250 * 10 ** DECIMALS, 'balanceOf is 3250 for investor2 who just received tokens');
  });

  it("can't buy tokens once crowdsale is finalized",
    async function () {
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    await tokenSaleDeployed.setBlockTimestamp(endTime + 1);
    await tokenSaleDeployed.checkFinalize();

    const value = web3.toWei(0.5, 'ether');
    await assertFail(async () => { await tokenSaleDeployed.sendTransaction({ from: investor, value: value }) });
    let isFinalized = await tokenSaleDeployed.isFinalized();
    assert.isTrue(isFinalized, "isFinalized should be true");
  });
});
