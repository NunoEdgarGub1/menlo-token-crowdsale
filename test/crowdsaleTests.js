'use strict';
var TokenSale = artifacts.require('./helpers/MenloTokenSaleMock.sol');
var METToken = artifacts.require('MenloToken.sol');

const assertFail = require("./helpers/assertFail");
import { latestTime, duration } from './helpers/latestTime';

const DECIMALS = 18;

contract('TokenSale', async function ([miner, owner, investor, investor2, wallet]) {
  let tokenSaleDeployed;
  let tokenDeployed;
  let startTime;
  beforeEach(async function () {
    tokenDeployed = await METToken.new();
    startTime = latestTime() + duration.seconds(1);
    const endTime = startTime + duration.weeks(6);
    const cap = web3.toWei(50000, 'ether');
    tokenSaleDeployed = await TokenSale.new(tokenDeployed.address, startTime, endTime, cap, wallet);
    await tokenSaleDeployed.setBlockTimestamp(startTime + duration.hours(1));
    await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);
  });

  it('should not be finalized', async function () {
    const isFinalized = await tokenSaleDeployed.isFinalized();
    assert.isFalse(isFinalized, "isFinalized should be false");
  });

  it('cap should be 50000 ETH', async function () {
    const cap = await tokenSaleDeployed.cap();
    assert.equal(cap.toString(10), '50000000000000000000000', "cap is incorrect");
  });

  describe('#whitelistAddresses', async function () {
    let investors;
    beforeEach(async function () {
      investors = [
        '0x2718C59E08Afa3F8b1EaA0fCA063c566BA4EC98B',
        '0x14ABEbe9064B73c63AEcd87942B0ED2Fef2F7B3B',
        '0x5850f06700E92eDe92cb148734b3625DCB6A14d4',
        '0xA38c9E212B46C58e05fCb678f0Ce62B5e1bc6c52',
        '0x7e2392A0DDE190457e1e8b2c7fd50d46ACb6ad4f',
        '0x0306D4C6ABC853bfDc711291032402CF8506422b',
        '0x1a91022B10DCbB60ED14584dC66B7faC081A9691'
      ];
    });
    it('should whitelist and blacklist', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses(investors, true);
      firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isTrue(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses(investors, false);
      firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);
    })

    it('allows to buy MET tokens at 30% bonus for duration of 1 hour', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 6500 * 10 ** DECIMALS, 'balanceOf is 6500 for investor who just bought tokens');
    });

    it('allows to buy MET tokens at 20% bonus rate after 1 hour for duration of 1 week', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(1));

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(10), 6000 * 10 ** DECIMALS, 'balanceOf is 6000 for investor who just bought tokens');
    });

    it('allows to buy MET tokens at 15% bonus rate after 1 weeks for duration of 1 week', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(2));

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(10), 5750 * 10 ** DECIMALS, 'balanceOf is 5750 for investor who just bought tokens');
    });

    it('allows to buy MET tokens at 10% bonus rate after 2 weeks for duration of 1 week', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(3));

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(10), 5500 * 10 ** DECIMALS, 'balanceOf is 5500 for investor who just bought tokens');
    });

    it('allows to buy MET tokens at 5% bonus rate after 3 weeks for duration of 1 week', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(4));

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(10), 5250 * 10 ** DECIMALS, 'balanceOf is 5250 for investor who just bought tokens');
    });

    it('allows to buy MET tokens at base rate after 4 weeks for duration until finalized', async function () {
      let firstInvestorStatus = await tokenSaleDeployed.whitelist(investors[0]);
      assert.isFalse(firstInvestorStatus);

      await tokenSaleDeployed.whitelistAddresses([investor], true);
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 0);

      await tokenSaleDeployed.setBlockTimestamp(startTime + duration.weeks(5));

      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(10), 5000 * 10 ** DECIMALS, 'balanceOf is 5000 for investor who just bought tokens');
    });

    it('cannot purchase MET tokens after the crowdsale is finalized', async function () {
      await tokenSaleDeployed.whitelistAddresses([investor], true);
      await tokenSaleDeployed.emergencyFinalize();
      const value = web3.toWei(1, 'ether');
      await assertFail(async () => {
        await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      });
    });

    it('cannot purchase MET tokens for the null address', async function () {
      // No whitelist for purchaser, or beneficiary (0x0)
      await assertFail(async () => {
        await tokenSaleDeployed.buyTokens(0x0, { from: investor, value: value });
      });
      // Whitelist for purchaser
      await tokenSaleDeployed.whitelistAddresses([investor], true);
      await assertFail(async () => {
        await tokenSaleDeployed.buyTokens(0x0, { from: investor, value: value });
      });
      // Whitelist for purchaser and beneficiary (0x0)
      // Should still fail even if someone whitelists the null address
      await tokenSaleDeployed.whitelistAddresses([0x0], true);
      await assertFail(async () => {
        await tokenSaleDeployed.buyTokens(0x0, { from: investor, value: value });
      });
    });

    it('cannot purchase MET tokens if the beneficiary is not whitelisted, even if you are', async function () {
      const value = web3.toWei(1, 'ether');
      await tokenSaleDeployed.whitelistAddresses([investor], true);
      await assertFail(async () => {
        await tokenSaleDeployed.buyTokens(investor2, { from: investor, value: value });
      });
      // Should work once the beneficiary has been whitelisted
      await tokenSaleDeployed.whitelistAddresses([investor2], true);
      await tokenSaleDeployed.buyTokens(investor2, { from: investor, value: value });
      let balance = await tokenDeployed.balanceOf(investor2);
      assert.equal(balance.toNumber(), 6500 * 10 ** DECIMALS, 'balanceOf is 6500 for investor who just bought tokens');
    });

    it('cannot purchase MET tokens if the beneficiary is not whitelisted', async function () {
      const value = web3.toWei(1, 'ether');
      await assertFail(async () => {
        await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      });
      // Should work once the beneficiary has been whitelisted
      await tokenSaleDeployed.whitelistAddresses([investor], true);
      await tokenSaleDeployed.sendTransaction({ from: investor, value: value });
      let balance = await tokenDeployed.balanceOf(investor);
      assert.equal(balance.toNumber(), 6500 * 10 ** DECIMALS, 'balanceOf is 6500 for investor who just bought tokens');
    });
  })
});
