const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');
const { request, gql } = require('graphql-request');
const { createImportSpecifier } = require("typescript");
const { ERROR_PREFIX } = require("hardhat/internal/core/errors-list.js");

async function main() {

    const [deployer] = await ethers.getSigners();
    let poolList = [];
    let poolTracker = new Map();
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

    const updateBot = () => {
        const query = gql`
        {
            loans(where:{outstanding:${true}}) {
                id
                borrower {
                    id
                }
                vault {
                    id
                }
                nft {
                    id
                }
                amount
                outstanding
            }
        
            auctions(where:{ended:${false}}) {
                id
                endTimestamp
                highestBid
                highestBidder
                ended
                closePoolContract
                nonce
            }
        }
        `

        request('https://api.thegraph.com/subgraphs/name/lauchness/abacus-spot-graph-goerli', query).then(data => {
            data.loans.forEach(element => {
                let nftInfo = element.nft.id.split('/');
                nftInfo[0] = nftInfo[0].toLowerCase();
                let grouping = nftInfo.join('/');
                loanTracker.set(grouping, {
                    nft: nftInfo[0],
                    id: nftInfo[1],
                    pool: element.vault.id,
                    amount: element.amount,
                    pendingLiq: false,
                });
                if(!loanList.includes(grouping)) {
                    loanList.push(grouping);
                }
            });
            data.auctions.forEach(element => {
                let nftInfo = element.id.split('/');
                poolList.push(element.closePoolContract);
                const newTrackerItem = {
                    nft: nftInfo[0],
                    id: nftInfo[1],
                    closureNonce: element.nonce,
                    bid: element.highestBid,
                    pool: element.closePoolContract,
                }
                const currentList = poolTracker.get(element.closePoolContract) ? poolTracker.get(element.closePoolContract) : [];
                const newTrackerList = [...currentList, newTrackerItem];
                poolTracker.set(element.closePoolContract, newTrackerList);
            });
        })
    }
    lend.on("EthBorrowed", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_amount} ETH borrowed by ${_user} against Spot pool at address ${_pool} using ${nft} ${id}`);
        nft = nft.toLowerCase();
        let grouping = [nft, id].join("/");
        let currentAmount = 0;
        if(loanTracker.get(grouping)) {
            currentAmount += parseInt(loanTracker.get(grouping).amount)
        }
        loanTracker.set(grouping, {
            nft,
            id,
            pool: _pool,
            amount: currentAmount + parseInt(_amount),
            pendingLiq: false,
        });
        if(!loanList.includes(grouping)) {
            loanList.push(grouping);
        }
    });

    lend.on("EthRepayed", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_amount} ETH repaid by ${_user} in relation to a loan taken against pool at address ${_pool} using ${nft} ${id}`);
        if(!(await lend.loanDeployed(nft, id))) {
            let grouping = [nft, id].join("/");
            removalIndex = loanList.findIndex(item => {
                return item === grouping
            });
            loanList.splice(removalIndex, 1);
            loanTracker.delete(grouping);
            console.log(`This loan has been settled!`);
        }
    });

    lend.on("BorrowerLiquidated", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_user} liquidated on a loan taken against pool at address ${_pool}. Auction starting for ${nft} ${id}`);
    });

    factory.on("NftClosed", (_pool,_adjustmentNonce,_closureNonce, _collection,_id,_caller,payout,closePoolContract, event) => {
        console.log(
            `
            ${_collection} ${_id} was closed into a Spot pool ${_pool} by ${_caller} in exchange for ${payout} wei and will now be auctioned off on ${closePoolContract}
            `
        );
    });

    factory.on("NewBid", async (_pool,_closureNonce, _closePoolContract,_collection,_id,_bidder,_bid, event) => {
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

    factory.on("AuctionEnded", async (_pool,_closureNonce,_closePoolContract,_collection,_id,_winner,_highestBid, event) => {
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
    updateBot();

    const liquidationCheck = async () => {
        console.log(loanList);
        for(let j = 0; j < loanList.length; j++) {
            let totalBids = 0;
            let bidAmount = 0;
            console.log("POOL:", loanTracker.get(loanList[j]).pool);
            vault = await Vault.attach(loanTracker.get(loanList[j]).pool);
            let tracker = poolTracker.get(await vault.closePoolContract());
            closure = await Closure.attach(await vault.closePoolContract());
            let currentEpoch = Math.floor(
                (Date.now() / 1000 - parseInt(await vault.startTime())) 
                / parseInt(await vault.epochLength())
            );
            let futureEpoch = Math.floor(
                (Date.now() / 1000 + parseInt(TIMEDIF) - parseInt(await vault.startTime()) + await vault.epochLength()/7.5) 
                / parseInt(await vault.epochLength())
            );
            console.log("Current and future epoch calculated");
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
            console.log("Bid information updated");
            let amountAuctions = parseInt(
                closure.address === ethers.constants.AddressZero ? 
                    0 : await closure.liveAuctions()
            );
            let currentPricePoint = (
                totalBids + 
                parseInt(await vault.amountNft() - amountAuctions) 
                    * parseInt(await vault.getTotalAvailableFunds(currentEpoch)) 
                        / parseInt(await vault.amountNft()))
                / (parseInt(await vault.amountNft() - amountAuctions) + bidAmount);
            let pricePoint = 
                (
                    totalBids + 
                    parseInt(await vault.amountNft() - amountAuctions) 
                        * parseInt(await vault.getTotalAvailableFunds(futureEpoch)) 
                            / parseInt(await vault.amountNft()))
                    / (parseInt(await vault.amountNft() - amountAuctions) + bidAmount);
            currentPricePoint = Math.floor(95 * currentPricePoint / 100);
            pricePoint = Math.floor(95 * pricePoint / 100);
            console.log("Current and future price point calculated");
            let poolLoans = loanList.filter(item =>item === loanList[j]);
            for(let k = 0; k < poolLoans.length; k++) {
                console.log("NFT:", poolLoans[k]);
                let loanTrack = loanTracker.get(poolLoans[k]);
                if(loanTrack.pendingLiq) {
                    console.log("SKIPPED");
                    continue;
                }
                console.log("Moving to check for eligible liquidation");
                let lateLiq = parseInt(loanTrack.amount) > currentPricePoint;
                payment = lateLiq ? loanTrack.amount : 0;
                if(pricePoint < parseInt(loanTrack.amount)) {
                    console.log("BANG, LIQUIDATED!");
                    console.log("PP of Liq:", pricePoint);
                    loanTrack.pendingLiq = true;
                    loanTracker.set(poolLoans[k], loanTrack);
                    console.log("UPDATED:", loanTracker.get(poolLoans[k]));
                    const liquidate = await lend.liquidate(
                        loanTrack.nft,
                        loanTrack.id,
                        addressList,
                        idList,
                        closureNonceList,
                        { value: payment.toString() } 
                    )
                        .catch((error) => {
                            console.log("REVERTED:", error.reason);
                            loanTrack.pendingLiq = false;
                            loanTracker.set(poolLoans[k], loanTrack);
                            console.log("UPDATED:", loanTracker.get(poolLoans[k]));
                            console.log('-----------');            
                            console.log("Starting new cycle...");
                            setTimeout(liquidationCheck, 5000);
                        });
                    liquidate.wait()
                        .then(txHash => {
                            let found = false;
                            txHash.events.forEach(item => {
                                if(
                                    item.eventSignature 
                                    && item.eventSignature == 'BorrowerLiquidated(address,address,address,uint256,uint256)'
                                ) {
                                    console.log("FOUND IT!")
                                    console.log(item.eventSignature);
                                    found = true;
                                }
                            });
                            if(found) {
                                console.log("Starting to search...");
                                console.log(`Filtering for ${poolLoans[k]}...`);
                                loanList = loanList.filter(item => {
                                    if(item == poolLoans[k]) {
                                        console.log("ITEM REMOVED:", item);
                                    }
                                    return item !== poolLoans[k];
                                });
                            }
                        })
                        .catch(error => {
                            console.log("Error thrown...");
                            loanTrack.pendingLiq = false;
                            loanTracker.set(poolLoans[k], loanTrack);
                            console.log("REVERTED:", loanTracker.get(poolLoans[k]));
                            console.log('-----------');            
                            console.log("Starting new cycle...");
                            setTimeout(liquidationCheck, 5000);
                        });
                }
            }
            console.log('-----------');
        }
        console.log("Starting new cycle...");
        setTimeout(liquidationCheck, 5000);
    }

    await liquidationCheck()

    // setInterval(async () => {
    //     console.log(loanList);
    //     for(let j = 0; j < loanList.length; j++) {
    //         let totalBids = 0;
    //         let bidAmount = 0;
    //         console.log("POOL:", loanTracker.get(loanList[j]).pool);
    //         vault = await Vault.attach(loanTracker.get(loanList[j]).pool);
    //         let tracker = poolTracker.get(await vault.closePoolContract());
    //         closure = await Closure.attach(await vault.closePoolContract());
    //         let currentEpoch = Math.floor(
    //             (Date.now() / 1000 - parseInt(await vault.startTime())) 
    //             / parseInt(await vault.epochLength())
    //         );
    //         let futureEpoch = Math.floor(
    //             (Date.now() / 1000 + parseInt(TIMEDIF) - parseInt(await vault.startTime()) + await vault.epochLength()/6) 
    //             / parseInt(await vault.epochLength())
    //         );
    //         console.log("CURRENT EPOCH:", currentEpoch);
    //         console.log(
    //             `TIME TO NEXT EPOCH:`, 
    //                 (currentEpoch + 1) * parseInt(await vault.epochLength()) 
    //                     + parseInt(await vault.startTime()) - (Date.now() / 1000 + parseInt(TIMEDIF))
    //         );
    //         if(currentEpoch < 0) continue;
    //         console.log(
    //             "Current payout:", parseInt(await vault.getPayoutPerReservation(currentEpoch)) 
    //         );
    //         console.log(
    //             "Future payout:", parseInt(await vault.getPayoutPerReservation(futureEpoch)) 
    //         );
    //         let addressList = new Array();
    //         let idList = new Array();
    //         let closureNonceList = new Array();
    //         if(tracker) {
    //             for(let k = 0; k < tracker.length; k++) {
    //                 let auctionEndTime = parseInt(await closure.auctionEndTime(
    //                         tracker[k].closureNonce, 
    //                         tracker[k].nft, 
    //                         tracker[k].id
    //                     )
    //                 );
    //                 if(auctionEndTime - 30 < Date.now() / 1000) {
    //                     totalBids += parseInt(tracker[k].bid); 
    //                     bidAmount += 1;
    //                     addressList.push(tracker[k].nft);
    //                     idList.push(tracker[k].id);
    //                     closureNonceList.push(tracker[k].closureNonce);
    //                 }
    //             }
    //         }
    //         let amountAuctions = parseInt(
    //             closure.address === ethers.constants.AddressZero ? 
    //                 0 : await closure.liveAuctions()
    //         );
    //         let currentPricePoint = (
    //             totalBids + 
    //             parseInt(await vault.amountNft() - amountAuctions) 
    //                 * parseInt(await vault.getTotalAvailableFunds(currentEpoch)) 
    //                     / parseInt(await vault.amountNft()))
    //             / (parseInt(await vault.amountNft() - amountAuctions) + bidAmount);
    //         let pricePoint = 
    //             (
    //                 totalBids + 
    //                 parseInt(await vault.amountNft() - amountAuctions) 
    //                     * parseInt(await vault.getTotalAvailableFunds(futureEpoch)) 
    //                         / parseInt(await vault.amountNft()))
    //                 / (parseInt(await vault.amountNft() - amountAuctions) + bidAmount);
    //         console.log(
    //             "Current price point:", Math.floor(95 * pricePoint / 100)
    //         );
    //         currentPricePoint = Math.floor(95 * currentPricePoint / 100);
    //         pricePoint = Math.floor(95 * pricePoint / 100);
    //         let poolLoans = loanList.filter(item =>item === loanList[j]);
    //         for(let k = 0; k < poolLoans.length; k++) {
    //             console.log("NFT:", poolLoans[k]);
    //             let loanTrack = loanTracker.get(poolLoans[k]);
    //             console.log("Outstanding:", parseInt(loanTrack.amount));
    //             let lateLiq = parseInt(loanTrack.amount) > currentPricePoint;
    //             payment = lateLiq ? loanTrack.amount : 0;
    //             console.log("Is this a late liquidation?", lateLiq);
    //             console.log("Payment size:", payment);
    //             if(pricePoint < parseInt(loanTrack.amount)) {
    //                 console.log("BANG, LIQUIDATED!");
    //                 const liquidate = await lend.liquidate(
    //                     loanTrack.nft,
    //                     loanTrack.id,
    //                     addressList,
    //                     idList,
    //                     closureNonceList,
    //                     { value: payment.toString() } 
    //                 );
    //                 liquidate.wait()
    //                     .then(txHash => {
    //                         let found = false;
    //                         txHash.events.forEach(item => {
    //                             if(
    //                                 item.eventSignature 
    //                                 && item.eventSignature == 'BorrowerLiquidated(address,address,address,uint256,uint256)'
    //                             ) {
    //                                 console.log("FOUND IT!")
    //                                 console.log(item.eventSignature);
    //                                 found = true;
    //                             }
    //                         });
    //                         if(found) {
    //                             console.log("Starting to search...");
    //                             loanList = loanList.filter(item => {
    //                                 console.log(`Filtering for ${poolLoans[k]}`);
    //                                 if(item == poolLoans[k]) {
    //                                     console.log("ITEM REMOVED:", item);
    //                                 }
    //                                 return item !== poolLoans[k];
    //                             });
    //                             console.log(loanList);
    //                         }
    //                     })
    //                     .catch(error => {
    //                         console.log(error);
    //                     });
    //             }
    //         }
    //         console.log('-----------');
    //     }
    // }, 10000);
}

main();

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
