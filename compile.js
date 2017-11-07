const assert = require('assert');
var fs = require("fs");
var solc = require('solc');
 
const Artifactor = require("truffle-artifactor"); 
const TruffleContract = require('truffle-contract');

const Web3 = require("web3");
const util = require('util');

const artifactor = new Artifactor("./build/contracts");
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const Contracts = ['SimpleToken', 'FrozenTokenHolder']

async function main() {
  console.log("Compiling contracts...");
    for (contract of Contracts){
      console.log("Compiling artifact "+contract);
      var input = fs.readFileSync("./contracts/"+contract+".sol");
      var output = solc.compile(input.toString(), 1);
      if (output.errors) {
        console.log(output.errors);
      }
      var bytecode = output.contracts[':'+contract].bytecode;
      var abi = JSON.parse(output.contracts[':'+contract].interface);
      await artifactor.save({contract_name: contract,  abi: abi, unlinked_binary: bytecode});
    }
    console.log("Done compiling");
}  

module.exports = main;