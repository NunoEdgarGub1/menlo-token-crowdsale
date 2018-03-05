# Menlo

The smart contracts for the [Menlo][menlo] token (MET) crowdsale.

![Menlo](Menlo.png)

## Contracts

Please see the [contracts/](contracts) directory.

## Develop

Contracts are written in [Solidity][solidity] and tested using [Truffle][truffle] and [ganache][ganache].

### Dependencies

```bash
# Install local node dependencies:
$ npm install
```

```bash
# Test
$ npm test
```

[menlo]: https://menlo.one
[ethereum]: https://www.ethereum.org/

[solidity]: https://solidity.readthedocs.io/en/develop/
[truffle]: http://truffleframework.com/
[ganache]: https://github.com/trufflesuite/ganache-cli

# Menlo Token Sale
In this document, we describe the token sale specification and implementation,
and give an overview over the smart contracts structure.

## Informal Specification
The token sale is open only to registered contributors.

In the sale, a bounded number of tokens is offered (e.g., there is hard cap for raised ether).

There will be two funding rounds where Menlo (MET) tokens may be purchased.

The first round will be in the form of a presale where 10% of the available tokens for sale will be available for purchase with a 35% discount with a lockup period achieved by the `MenloTokenTimelock.sol` contract.

Corresponding token balances can be claimed after the lockup period by calling the `release` function from each `msg.sender`.

The second round will be in the form of the main sale where 90% of the available tokens for sale will be available for purchase at a scheduled bonus rate per week with a bonus power hour from the sale going live.

Preminted tokens are allocated to the company growth fund and team by the `MenloTokenVesting.sol` contract subject to a cliff period.

## Detailed description

### Overview of flow

1. Firstly `MenloToken.sol` is deployed and 1 billion MET tokens are minted to the owner address. This is a fixed supply and no more MET can ever be created.

2. We deploy `MenloTokenPresale.sol` and list contributors who have been whitelist approved upon passing KYC procedures.
The listing is done by us with a standard private key and whitelisting script.

2. The presale tokens are transferred to the `MenloTokenPresale.sol` contract by calling `initializePresale` inside of `MenloToken.sol` from the contract owner.

3. The `TokenTimeLock.sol` contract is deployed where all presale tokens purchased will be sent to immediately upon purchase and stored on behalf of each contributor. It is required to call `setTokenTimeLock` in `MenloTokenPresale.sol` once this contract has been deployed.

4. The address used for whitelisting is assigned by `setWhitelister` in the `MenloTokenPresale.sol` contract.

5. Contributors addresses are collected during the KYC process and stored in `ARRAY_OF_ADDRESSES.json`. By running the `whitelist_signed.js` script, batches of addresses are added as approved purchasers. Without a whitelisted address, purchasing MET during the presale will not be possible.

6. The presale starts. At this point contributors can buy tokens by sending ETH to the `MenloTokenPresale.sol` contract address directly, or alternatively by calling the `buyTokens()` function.
It is possible to buy several times, as long as cap is not exceeded.

7. As a result of either the endTime or cap being met, unsold tokens are sent back to the company wallet upon calling `refund` from the `MenloToken.sol` owner address.

8. Token transfers are enabled by calling `unpause` by the `MenloToken.sol `owner address.

9. The same process will be repeated for deployment of `MenloTokenSale.sol` using steps 2, 3, 5, 6, 7, 8 and 9. The tokens allocated for the main sale will be sent to the contract by calling `initializeCrowdsale` inside of `MenloToken.sol` from the contract owner. All tokens purchased will be sent directly to the beneficiary address immediately upon calling `buyTokens`.

### Per module description
The system has 3 modules, namely, whitelisting, token, and token sale modules.

#### Whitelist
Implemented in `MenloTokenPresale.sol` and `MenloTokenSale.sol`.
Provides a raw list of addresses approved for purchase.

#### Token
Implemented in `MenloToken.sol`. The token is fully compatible with ERC20 standard.

It is impossible to transfer tokens during the period of the token sale.
To be more precise, only the token sale contract is allowed to transfer tokens during the token sale.

The token contract has the role of:

Distributing preminted tokens. Implemented in `MenloToken.sol` and `MenloTokenVesting.sol`

#### Token sale
The token sale contracts have the roles of:

Verifying that contributors are whitelisted. Implemented in `MenloTokenPresale.sol` and `MenloTokenSale.sol`.

Distributing tokens to buyers. Implemented in `MenloTokenTimelock.sol`, `MenloTokenPresale.sol` and `MenloTokenSale.sol`.

### Use of zeppelin code
We use Open Zeppelin code for `SafeMath`, `Ownable`, `ERC20Basic`, `PausableToken`, `BurnableToken` and `StandardToken` logic.

We decided to modify the standard `TokenTimeLock.sol` found in the Open Zeppelin library to handle holding tokens for multiple beneficiaries rather than just one at a time, and we expect the auditor to review these changes.
Changes are denoted with `MENLO-NOTE!` comment in contract file.
