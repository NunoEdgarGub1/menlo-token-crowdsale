'use strict';
var TokenSale = artifacts.require('./helpers/MenloTokenSaleMock.sol');
var METToken = artifacts.require('./helpers/MenloTokenMock.sol');

import { latestTime, duration } from './helpers/latestTime';
const BigNumber = require("bignumber.js");
const assertFail = require("./helpers/assertFail");
require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should()
const expect = require('chai').expect

const DECIMALS = 18;

contract('Audit Tests', async function ([deployer, investor, crowdsale_wallet]) {
  let tokenSaleDeployed;
  let tokenDeployed;
  let startTime;
  let endTime;

    it('Initializing the MenloToken contract should emit a transfer event which generates the tokens', async function () {
      tokenDeployed = await METToken.new();
      let event = tokenDeployed.Transfer({});
      event.watch(function(err, res) {
        if (!err) {
          assert.equal(res['event'], 'Transfer');
          event.stopWatching();
        }
    });
  });

    it('Cannot deploy crowdsale if the cap is 0', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => {
        tokenSaleDeployed = await TokenSale.new(
        tokenDeployed.address,
        latestTime() + duration.seconds(17),
        latestTime() + duration.weeks(3),
        0
      )
    });
  });

    it('Cannot deploy crowdsale if the token is null', async function () {
      await assertFail(async () => {
      tokenSaleDeployed = await TokenSale.new(
        0x0,
        latestTime() + duration.seconds(15),
        latestTime() + duration.weeks(6),
        12345
      )
    });
  });

    it('Cannot deploy crowdsale if the token is null', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => {
      tokenSaleDeployed = await TokenSale.new(
        tokenDeployed.address,
        latestTime() + duration.seconds(19),
        latestTime() + duration.weeks(2),
        12345,
        0x0
      )
    });
  });

    it('Cannot deploy crowdsale if the start time is in the past', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => {
      tokenSaleDeployed = await TokenSale.new(
        tokenDeployed.address,
        latestTime() - duration.seconds(2),
        latestTime() + duration.weeks(1),
        12345
      )
    });
  });

    it('Cannot deploy crowdsale if the end time is before the start time', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => {
      tokenSaleDeployed = await TokenSale.new(
        tokenDeployed.address,
        latestTime() + duration.weeks(10),
        latestTime() + duration.weeks(1),
        12345
      )
    });
  });

    it('Cap should not be able to exceed balance of crowdsale contract', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => {
      await TokenSale.new(
        tokenDeployed.address,
        latestTime() + duration.seconds(20),
        latestTime() + duration.weeks(1),
        web3.toWei(150000001, 'ether')
      )
    });
  });

    it('Tokens should not be able to be sent to the null address from the token contract', async function () {
      tokenDeployed = await METToken.new();
      await assertFail(async () => { await tokenDeployed.transfer(0x0, tokenDeployed.address) });
    });

    describe('Deploy Contracts', async function () {
    beforeEach(async function () {
      startTime = latestTime() + duration.seconds(20);
      endTime = startTime + duration.weeks(1);
      const cap = web3.toWei(15000, 'ether');

      tokenDeployed = await METToken.new();
      tokenSaleDeployed = await TokenSale.new(tokenDeployed.address, startTime, endTime, cap, crowdsale_wallet);
    });

    it('Calling an invalid function on the token triggers the fallback and reverts', async function () {
      await assertFail(async () => {
      await tokenDeployed.sendTransaction({ from: investor })
      });
    });

    it('Crowdsale should only be able to be initialized once', async function () {
      await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);
      await assertFail(async () => { await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address) });;
    });

    it('After deploying the MenloToken and the Crowdsale, the balances should all be correct', async function () {
      assert.equal((await tokenDeployed.balanceOf(deployer)).toNumber(), 1000000000 * 10 ** DECIMALS, "The Token deployer should hold 1 bil");
      assert.equal((await tokenDeployed.balanceOf(tokenSaleDeployed.address)).toNumber(), 0, "The Crowdsale should have no balance");

      await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);

      assert.equal((await tokenDeployed.balanceOf(deployer)).toNumber(), 730000000 * 10 ** DECIMALS, "The Token deployer should hold 1 730 mil");
      assert.equal((await tokenDeployed.balanceOf(tokenSaleDeployed.address)).toNumber(), 270000000 * 10 ** DECIMALS, "The Crowdsale should hold 270 mil");
    });

    describe('Initialize crowdsale', async function () {
      beforeEach(async function () {
        await tokenDeployed.initializeCrowdsale(tokenSaleDeployed.address);
        await tokenSaleDeployed.whitelistAddresses([investor], true);
    });

    it('Only the owner can unpause token transfers', async function () {
      await assertFail(async () => { await tokenDeployed.unpause({ from: deployer }) });
      await assertFail(async () => { await tokenDeployed.unpause({ from: investor }) });
      await assertFail(async () => { await tokenDeployed.unpause({ from: crowdsale_wallet }) });
      await assertFail(async () => { await tokenDeployed.unpause({ from: presale_wallet }) });
    })

    it('Tokens should not be able to be refunded before the Crowdsale is finished', async function () {
      await tokenSaleDeployed.setBlockTimestamp(startTime + 1);
      await assertFail(async () => { await tokenSaleDeployed.refund() });
    });

    it('Tokens should not be able to be sent to the null address by the crowdsale', async function () {
      await tokenSaleDeployed.setBlockTimestamp(startTime + 1);
      await assertFail(async () => { await tokenSaleDeployed.buyTokens(0x0, { from: investor });
      });
    });

    it('Token Ownership should be transferred when crowdsale is finalized', async function () {
      assert.equal(await tokenDeployed.owner.call(), tokenSaleDeployed.address);
      await tokenSaleDeployed.setBlockTimestamp(endTime + 1);
      await tokenSaleDeployed.checkFinalize();
      assert.equal(await tokenDeployed.owner.call(), deployer);
      });
    });
  });
});
