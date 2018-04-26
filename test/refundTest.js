'use strict';
var TokenSale = artifacts.require('./helpers/MenloTokenSaleMock.sol');
var METToken = artifacts.require('./helpers/MenloTokenMock.sol');
const assertFail = require("./helpers/assertFail");

import { latestTime, duration } from './helpers/latestTime';

const DECIMALS = 18;

contract('TokenSaleRefund', async function ([miner, owner, investor, wallet, whitelister]) {
  let tokenSaleDeployed;
  let tokenDeployed;
  let startTime;

  beforeEach(async function () {
    tokenDeployed = await METToken.new();
    startTime = latestTime() + duration.seconds(1);
    const endTime = startTime + duration.weeks(6);
    const cap = web3.toWei(1, 'ether');
    tokenSaleDeployed = await TokenSale.new(tokenDeployed.address, startTime, endTime, cap, wallet);
    await tokenSaleDeployed.setWhitelister(whitelister);
    await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);
  });

  it('refund excess ETH if contribution is above cap (week 5)', async function () {
    // set to WEEK5 without bounus
    await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(5));
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    let investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);

    const value = web3.toWei(1.1, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' });

    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 5000 * 10 ** DECIMALS);
  });

  it('refund excess ETH if contribution is above cap (week 1)', async function () {
    await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(1));
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    let investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);

    const value = web3.toWei(3, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' });

    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6000 * 10 ** DECIMALS);
  });

  it('refund excess ETH in multiple contributions if contributions are above cap (week 1)', async function () {
    await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(1));
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    let investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);

    let value = web3.toWei(0.99, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' });

    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 5940 * 10 ** DECIMALS);

    value = web3.toWei(1, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' });

    balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6000 * 10 ** DECIMALS);
  });

  it('trying to whitelist an address twice doesn\'t change it\'s state', async function () {
    let investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isFalse(investorStatus);
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});
    investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);

    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});
    investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);
  });

  it('refund excess ETH if cap has been exceeded (week 1)', async function () {
    await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(1));
    await tokenSaleDeployed.whitelistAddresses([investor], true, {from: whitelister});

    let investorStatus = await tokenSaleDeployed.whitelist(investor);
    assert.isTrue(investorStatus);

    let value = web3.toWei(1, 'ether');
    await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' });

    let balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6000 * 10 ** DECIMALS);

    value = web3.toWei(10, 'ether');
    await assertFail(async () => { await tokenSaleDeployed.sendTransaction({ from: investor, value: value, gas: '200000' })});

    balance = await tokenDeployed.balanceOf(investor);
    assert.equal(balance.toNumber(), 6000 * 10 ** DECIMALS);
  });
});
