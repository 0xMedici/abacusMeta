const { BigNumber } = require("ethers");
const { ethers } = require("hardhat");
const { ADDRESSES } = require('./Addresses.js');

async function main() {

    const [deployer] = await ethers.getSigners();
    let poolList = [];
    const poolTracker = new Map();
    let loanList = [];
    let loanTracker = new Map();
 
    provider = ethers.getDefaultProvider();

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Lend = await ethers.getContractFactory("Lend");
    lend = await Lend.attach(ADDRESSES[2]);
    console.log("Lend connected.", lend.address);

    Vault = await ethers.getContractFactory("Vault");
    Closure = await ethers.getContractFactory("Closure");

    lend.on("EthBorrowed", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_amount} ETH borrowed by ${_user} against Spot pool at address ${_pool} using ${nft} ${id}`);
        let grouping = nft + id;
        let currentAmount = 0;
        if(loanTracker.get(grouping)) {
            currentAmount += parseInt(loanTracker.get(grouping).amount)
        }
        loanTracker.set(grouping, {
            nft,
            id,
            pool: _pool,
            amount: currentAmount + parseInt(_amount)
        });
        loanList.push(grouping);
    });

    lend.on("EthRepayed", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_amount} ETH repaid by ${_user} in relation to a loan taken against pool at address ${_pool} using ${nft} ${id}`);
        if(!(await lend.loanDeployed(nft, id))) {
            let grouping = nft + id;
            removalIndex = loanList.findIndex(item => {
                return item === grouping
            });
            loanList.splice(removalIndex, 1);
            console.log(`This loan has been settled!`);
        }
    });

    lend.on("BorrowerLiquidated", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_user} liquidated on a loan taken against pool at address ${_pool}. Auction starting for ${nft} ${id}`);
        let grouping = nft + id;
        removalIndex = loanList.findIndex(item => {
            return item === grouping
        });
        loanList.splice(removalIndex, 1);
    });

    factory.on("NftClosed", (_pool,_collection,_id,_caller,payout,closePoolContract, event) => {
        console.log(
            `
            ${_collection} ${_id} was closed into a Spot pool ${_pool} by ${_caller} in exchange for ${payout} wei and will now be auctioned off on ${closePoolContract}
            `
        );
    });

    factory.on("NewBid", async (_pool,_closePoolContract,_collection,_id,_bidder,_bid, event) => {
        console.log(`New bid of ${_bid} for ${_collection} ${_id} has been submitted by ${_bidder}!`);
        closure = await Closure.attach(_closePoolContract);
        const closureNonce = await closure.nonce(_collection, _id);
        poolList.push(_closePoolContract);
        const newTrackerItem = {
            nft: _collection,
            id: _id,
            closureNonce: closureNonce,
            bid: _bid,
            pool: _pool,
        }
        const currentList = poolTracker.get(_closePoolContract.toString()) ? poolTracker.get(_closePoolContract.toString()) : [];
        const newTrackerList = [...currentList, newTrackerItem];
        poolTracker.set(_closePoolContract.toString(), newTrackerList);
    });

    factory.on("AuctionEnded", async (_pool,_closePoolContract,_collection,_id,_winner,_highestBid, event) => {
        console.log(`Auction for ${_collection} ${_id} ended with a winning bid of ${_highestBid} submitted by ${_winner}!`);
        closure = await Closure.attach(_closePoolContract);
        closureNonce = await closure.nonce(_collection, _id);
        closureTracker = poolTracker.get(_closePoolContract.toString()).filter(item => {
            return item.nft !== _collection && item.id !== _id
        });
        removalIndex = poolList.findIndex(item => {
            return item === _closePoolContract
        });
        poolList.splice(removalIndex, 1);
        poolTracker.set(_closePoolContract.toString(), closureTracker);
    });

    setInterval(async () => {
        console.log(loanList);
        for(let j = 0; j < loanList.length; j++) {
            let totalBids = 0;
            let bidAmount = 0;
            vault = await Vault.attach(loanTracker.get(loanList[j]).pool);
            let tracker = poolTracker.get(await vault.closePoolContract());
            closure = await Closure.attach(loanList[j]);
            let currentEpoch = Math.floor(
                (Date.now() / 1000 - parseInt(await vault.startTime())) 
                / parseInt(await vault.epochLength())
            );
            let futureEpoch = Math.floor(
                (Date.now() / 1000 - parseInt(await vault.startTime()) + await vault.epochLength()/6) 
                / parseInt(await vault.epochLength())
            );
            console.log("CURRENT EPOCH:", currentEpoch);
            console.log(
                `TIME TO NEXT EPOCH:`, 
                    (currentEpoch + 1) * parseInt(await vault.epochLength()) 
                        + parseInt(await vault.startTime()) - Date.now() / 1000
            );
            if(currentEpoch < 0) continue;
            console.log(
                "Current payout:", parseInt(await vault.getPayoutPerReservation(currentEpoch)) 
            );
            console.log(
                "Future payout:", parseInt(await vault.getPayoutPerReservation(futureEpoch)) 
            );
            let addressList = new Array();
            let idList = new Array();
            let closureNonceList = new Array();
            if(tracker) {
                for(let k = 0; k < tracker.length; k++) {
                    let auctionEndTime = parseInt(await closure.auctionEndTime(
                            tracker[k].closureNonce, 
                            tracker[k].nft, 
                            tracker[k].id
                        )
                    );
                    if(auctionEndTime - 30 < Date.now() / 1000) {
                        totalBids += parseInt(tracker[k].bid); 
                        bidAmount += 1;
                        addressList.push(tracker[k].nft);
                        idList.push(tracker[k].id);
                        closureNonceList.push(tracker[k].closureNonce);
                    }
                }
            }
            let pricePoint = 
                (
                    totalBids + 
                    parseInt(await vault.reservationsAvailable()) 
                        * parseInt(await vault.getTotalAvailableFunds(futureEpoch)) 
                            / parseInt(await vault.amountNft()))
                    / (parseInt(await vault.reservationsAvailable()) + bidAmount);
            console.log(
                "Current price point:", Math.floor(95 * pricePoint / 100)
            );
            let poolLoans = loanList.filter(item =>item === loanList[j]);
            for(let k = 0; k < poolLoans.length; k++) {
                let loanTrack = loanTracker.get(poolLoans[k]);
                if(pricePoint < 95 * parseInt(loanTrack.amount) / 100) {
                    console.log("BANG, LIQUIDATED!");
                    await lend.liquidate(
                        loanTrack.nft,
                        loanTrack.id,
                        addressList,
                        idList,
                        closureNonceList
                    );
                }
            }
            console.log("--------------");
        }
    }, 6000);
}

main();

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
