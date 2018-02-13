const contract = require("truffle-contract");
const MenloTokenPresaleABI = require("../build/contracts/MenloTokenPresale.json");
const MenloTokenPresale = contract(MenloTokenPresaleABI);
const Web3 = require("web3");
var web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:8545"));

const fs = require("fs");

var _ = require("lodash");
var Papa = require("papaparse");
var sleep = require("sleep");

MenloTokenPresale.setProvider(web3.currentProvider);

const CHUNK_LENGTH = 130;

let ADDRESSES = fs.readFileSync("./presale_whitelisted.csv", { encoding: "utf8" });

const MENLOTOKEN_PRESALE_ADDRESS = "0x";
const MENLOTOKEN_PRESALE_OWNER = "0x";

let txConfirmation;
let isWhitelisted;

let parsedAddresses = Papa.parse(ADDRESSES);
let flattenedAddresses = _.compact(_.flattenDeep(parsedAddresses.data));
let dedupedAddresses = _.uniq(flattenedAddresses);
let chunkedAddresses = _.chunk(dedupedAddresses, CHUNK_LENGTH);

console.log("TOTAL ADDRESSES : ", flattenedAddresses.length);
console.log("UNIQUE ADDRESSES : ", dedupedAddresses.length);
console.log("TRANSACTIONS TO RUN : ", chunkedAddresses.length);

// UNCOMMENT ME WHEN YOU ARE READY TO GO LIVE AND COMMENT BELOW!
_.forEach(chunkedAddresses, function(chunk) {
   whitelist(chunk);
});

async function whitelist(addresses) {
  try {
    let instance = await MenloTokenPresale.at(MENLOTOKEN_PRESALE_ADDRESS);

    // send only if the last address was whitelisted
    // https://github.com/ethereum/web3.js/issues/1089#issuecomment-342184640
    isWhitelisted = await web3.eth.call({
      to: MENLOTOKEN_PRESALE_ADDRESS,
      data: instance.methods.whitelist(_.last(addresses)).encodeABI()
    });

    let result = web3.utils.hexToNumber(isWhitelisted);
    if (result == 1) {
      console.log("LAST ADDRESS IS ALREADY WHITELISTED : ", isWhitelisted);
    } else {
      // Waits for 10 secs so we don't hammer the node
      sleep.msleep(20);
      console.log("SENT AT : ", new Date());
      console.log("NUMBER OF ADDRESSES TO WHITELIST : ", addresses.length);
      try {
        txConfirmation = await instance.whitelistAddresses(addresses, {
          from: MENLOTOKEN_PRESALE_OWNER,
          gas: 3700000
        });
      } catch (err) {
        console.log(err);
      }
      console.log("GAS USED : ", txConfirmation.receipt.gasUsed);
      console.log("TX HASH : ", txConfirmation.receipt.transactionHash);
    }
    console.log(
      "RANDOM ADDRESS TO TEST : ",
      addresses[_.random(0, addresses.length - 1, false)]
    );
    console.log("FIRST ADDRESS TO TEST : ", _.first(addresses));
    console.log("LAST ADDRESS TO TEST : ", _.last(addresses));
  } catch (err) {
    console.log(err);
  }
}
