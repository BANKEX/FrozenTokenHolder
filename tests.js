#!/usr/bin/env node
const assert = require('assert');
const comp = require('./compile');
const moment = require('moment');
const coinstring = require('coinstring');
var fs = require("fs");
var solc = require('solc');
var Artifactor = require("truffle-artifactor"); 
var async = require("async");
var TestRPC = require("ethereumjs-testrpc");
var TruffleContract = require('truffle-contract');
var Web3 = require("web3");
const util = require('util');
var FrozenHolderContract;
var LedgerContract;
var DeployedFrozenHolderContract;
var DeployedLedgerContract;
var allAccounts;
var fromBtcWif = coinstring.createDecoder(0x80);
var DECIMAL_MULTIPLIER_BN;
var web3;
var BigNumber;
var sendAsyncPromisified;
var getBlockNumberPromisified;
var getBalancePromisified;
var getAccountsPromisified;

const SET_DECIMALS = 9;

function startVM(){
    var provider = TestRPC.provider({
        total_accounts: 10,
        time:new Date(),
        verbose:false,
        gasPrice: 0,
      accounts:[
          {secretKey:"0x7231a774a538fce22a329729b03087de4cb4a1119494db1c10eae3bb491823e7", balance: 1e30},
          {secretKey:"0x"+fromBtcWif("5JmrM8PB2d5XetmVUCErMZYazBotNzSeMrET26WK8y3m8XLJS98").toString('hex'), balance: 1e30},
          {secretKey:"0x"+fromBtcWif("5HtkDncwskEM5FiBQgU1wqLLbayBmfh5FSMYtLngedr6C6NhvWr").toString('hex'), balance: 1e30},
          {secretKey:"0x"+fromBtcWif("5JMneDeCfBBR1M6mX7SswZvC8axrfxNgoYKtu5DqVokdBwSn2oD").toString('hex'), balance: 1e30}    
      ],
        mnemonic: "42"
        // ,
        // logger: console
      });
      web3 = new Web3(provider);
      BigNumber = web3.BigNumber;
      sendAsyncPromisified = util.promisify(provider.sendAsync).bind(provider);
      var tmp_func = web3.eth.getBalance;
      delete tmp_func['call'];
      getBlockNumberPromisified= util.promisify(web3.eth.getBlockNumber);
      getBalancePromisified = util.promisify(tmp_func).bind(web3.eth);
      DECIMAL_MULTIPLIER_BN = new BigNumber(10**SET_DECIMALS);
      getAccountsPromisified = util.promisify(web3.eth.getAccounts);
}




function getBalance(address) {
    return async function(){
        var res = await getBalancePromisified.call(web3.eth, address);
        return res;
    }
}

function getTokenBalance(address) {
    return async function(){
        var res = await DeployedLedgerContract.balanceOf(address);
        return res;
    }
}

function printResultsArray(results){
    results.forEach((el) => {
        if (el.__proto__ && el.__proto__.constructor.name == "BigNumber"){
            console.log(el.toNumber());
        }
        else if (typeof el == "string"){
            console.log(el);
        }
        else if (typeof el == "boolean"){
            console.log(el);
        }
        else{
            console.log(web3.toAscii(el));
        }
    })
}

function jump(duration) {
    return async function() {
    //   console.log("Jumping " + duration + "...");

      var params = duration.split(" ");
      params[0] = parseInt(params[0])

      var seconds = moment.duration.apply(moment, params).asSeconds();
      await sendAsyncPromisified({
        jsonrpc: "2.0",
        method: "evm_increaseTime",
        params: [seconds],
        id: new Date().getTime()
        });
    }
}



function deployContracts() {
    return async function() {
        try{
            console.log("Deploying contract...");
            const name = "TEST";
            const ticker = "TST"; 
            DeployedLedgerContract = await LedgerContract.new(name, ticker, SET_DECIMALS);
            DeployedFrozenHolderContract = await FrozenHolderContract.new(DeployedLedgerContract.address);
            var res = await DeployedLedgerContract.mintSomeone(DeployedFrozenHolderContract.address, 1e12);
            res = await getTokenBalance(DeployedFrozenHolderContract.address)();
            res = await DeployedFrozenHolderContract.updateBalanceFromParent();
            console.log("Deployed");
        }
        catch(err){
            console.log(err)
        }
    }
}

function mine(numBlocks){
    return async function() {
    console.log("Mining a block");
    for (var i=0; i< numBlocks; i++){
        await sendAsyncPromisified({
                jsonrpc: "2.0",
                method: "evm_mine",
                params: [],
                id: new Date().getTime()
        });
    }
    }
}

function populate_def_acc(){
    return function(callback){ 
     web3.eth.getAccounts(function(err, accounts) {
        if (err || !accounts){
            console.log(err);
            console.log("Second entry")
            return;
        }
        allAccounts = accounts;
        callback();
     });
    }
}

async function populateAccounts(){
    allAccounts = await getAccountsPromisified();
    LedgerContract = new TruffleContract(require("./build/contracts/SimpleToken.json"));
    FrozenHolderContract = new TruffleContract(require("./build/contracts/FrozenTokenHolder.json"));
    [LedgerContract, FrozenHolderContract].forEach(function(contract) {
        contract.setProvider(web3.currentProvider);
        contract.defaults({
        gas: 3.5e6,
        from: allAccounts[0]
        })
    });
}

async function runTests() {
    try{
        await comp();    
        await startVM();
        await populateAccounts();
        await deployContracts()();
        var res = await DeployedFrozenHolderContract.setDestination(allAccounts[2], true);
        res = await DeployedFrozenHolderContract.purchaseFor(allAccounts[1], 1e10, false);
        res = await DeployedFrozenHolderContract.purchaseFor(allAccounts[1], 1e10, false);
        var balanceIndexes = await DeployedFrozenHolderContract.balanceStructureIndexes(allAccounts[1]);
        printResultsArray(balanceIndexes);
        for (var ind of balanceIndexes){
            console.log(ind.toNumber());
            res = await DeployedFrozenHolderContract.checkBalanceStructure(allAccounts[1], ind);
            printResultsArray(res);
        }
        res = await DeployedFrozenHolderContract.transfer(allAccounts[2], 15e9, {from: allAccounts[1]});
        console.log("\n After large transfer \n");
        var balanceIndexes2 = await DeployedFrozenHolderContract.balanceStructureIndexes(allAccounts[1]);
        printResultsArray(balanceIndexes2);
        for (var ind of balanceIndexes2){
            console.log(ind.toNumber());
            res = await DeployedFrozenHolderContract.checkBalanceStructure(allAccounts[1], ind);
            printResultsArray(res);
        }
        var receiverBalance = await getTokenBalance(allAccounts[2])();
        assert(receiverBalance.toNumber() > 0);
        await jump("366 days")();
        res = await DeployedFrozenHolderContract.transfer(allAccounts[0], 1e9, {from: allAccounts[1]});
        receiverBalance = await getTokenBalance(allAccounts[0])();
        assert(receiverBalance.toNumber() > 0);
        res = await DeployedFrozenHolderContract.increaseApproval(allAccounts[0], 2e9, {from: allAccounts[1]});
        res = await DeployedFrozenHolderContract.allowance(allAccounts[1], allAccounts[0]);
        assert(res.toNumber() > 0);
        res = await DeployedFrozenHolderContract.transferFrom(allAccounts[1], allAccounts[0], 1e9, {from: allAccounts[0]});
        var receiverBalance2 = await getTokenBalance(allAccounts[0])();
        assert(receiverBalance2.gt(receiverBalance));
        console.log("Test done");
    }
    catch(err){
        console.log(err);
        console.log("Test failed")
        return;
    }
    console.log("Test successful")
}

runTests()
