const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');
const { request, gql } = require('graphql-request');
const { createImportSpecifier, tokenToString } = require("typescript");
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
    MockToken = await ethers.getContractFactory("MockToken");
    token = await MockToken.attach(ADDRESSES[4]);

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
        }
        `

        request('https://api.thegraph.com/subgraphs/name/0xmedici/abacusgraphdev', query).then(data => {
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

    updateBot();

    const liquidationCheck = async () => {
        console.log(loanList);
        for(let j = 0; j < loanList.length; j++) {
            console.log("POOL:", loanTracker.get(loanList[j]).pool);
            vault = await Vault.attach(loanTracker.get(loanList[j]).pool);
            let poolStartTime = parseInt(await vault.startTime());
            let currentEpoch = Math.floor(
                (Date.now() / 1000 - poolStartTime)
                / parseInt(await vault.epochLength())
            );
            let futureEpoch = Math.floor(
                (Date.now() / 1000 + parseInt(TIMEDIF) - poolStartTime + await vault.epochLength()/7.5) 
                / parseInt(await vault.epochLength())
            );
            console.log("Current and future epoch calculated");
            console.log("CURRENT EPOCH:", currentEpoch);
            console.log(
                `TIME TO NEXT EPOCH:`, 
                    (currentEpoch + 1) * parseInt(await vault.epochLength()) 
                        + poolStartTime - Date.now() / 1000
            );
            if(currentEpoch < 0) continue;
            let currentPricePoint = parseInt(await vault.getPayoutPerReservation(futureEpoch))
            console.log(
                "Current payout:", parseInt(await vault.getPayoutPerReservation(currentEpoch)) 
            );
            console.log(
                "Future payout:", parseInt(await vault.getPayoutPerReservation(futureEpoch)) 
            );
            let pricePoint = 0.95 * currentPricePoint;
            let poolLoans = loanList.filter(item =>item === loanList[j]);
            for(let k = 0; k < poolLoans.length; k++) {
                console.log("NFT:", poolLoans[k]);
                let loanTrack = loanTracker.get(poolLoans[k]);
                if(loanTrack.pendingLiq) {
                    console.log("SKIPPED");
                    continue;
                }
                console.log("Moving to check for eligible liquidation");
                let lateLiq = parseInt(loanTrack.amount) > pricePoint;
                payment = lateLiq ? loanTrack.amount : 0;
                if(pricePoint < parseInt(loanTrack.amount)) {
                    console.log("BANG, LIQUIDATED!");
                    console.log("PP of Liq:", pricePoint);
                    loanTrack.pendingLiq = true;
                    loanTracker.set(poolLoans[k], loanTrack);
                    console.log("UPDATED:", loanTracker.get(poolLoans[k]));
                    await token.approve(lend.address, payment.toString());
                    const liquidate = await lend.liquidate(
                        loanTrack.nft,
                        loanTrack.id
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
}

main();

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
