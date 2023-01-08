const { ethers } = require("hardhat");
const { ADDRESSES, TIMEDIF } = require('./Addresses.js');
const { request, gql } = require('graphql-request');
const { boolean } = require("hardhat/internal/core/params/argumentTypes.js");

async function main() {

    const [deployer] = await ethers.getSigners();
    provider = ethers.getDefaultProvider();
    let activeNonces = [];
    let nonceMap = new Map();
    let positionMap = new Map();
    let adjustmentMap = new Map();
    let cancelledMap = new Map();

    Factory = await ethers.getContractFactory("Factory");
    factory = await Factory.attach(ADDRESSES[1]);
    console.log("Factory connected.", factory.address);
    Sub = await ethers.getContractFactory("Sub");
    sub = await Sub.attach(ADDRESSES[5]);
    console.log("Sub connected.", sub.address);

    MockToken = await ethers.getContractFactory("MockToken");
    Vault = await ethers.getContractFactory("Vault");
    Position = await ethers.getContractFactory("Position");

    const updateBot = () => {
        const queryStatus = gql`
        {
            subs {
              id
              user {
                      id
              }
              vault {
                      id
              }
              status
              nonce
              tranches
              amounts
              lockTime
              positionNonces
            }
        }
        `

        request('https://api.thegraph.com/subgraphs/name/alcltzp/abacus-spot-graph-goerli-test', queryStatus).then(data => {
            data.subs.forEach(element => {
                if(element.status !== 0 || Boolean(element.positionNonces[0])) {
                    if(!activeNonces.includes(element.nonce)) {
                        activeNonces.push(element.nonce);
                        nonceMap.set(element.nonce, {
                            pendingPurchase: false,
                            pendingAdjustment: false,
                            pendingSale: false,
                            vault: element.vault,
                            tickets: element.tranches,
                            amounts: element.amounts,
                        });
                        let positionNonces = new Array();
                        element.positionNonces.forEach(element => {
                            positionNonces.push(parseInt(element));
                        })
                        positionMap.set(parseInt(element.nonce), positionNonces);
                        if(element.status === 0) {
                            cancelledMap.set(parseInt(element.nonce), true);
                        }
                    }
                }
            });
        })
    }

    const updateAdjustmentMap = (adjustmentNonce) => {
        const query = gql`
            {
                auctions(where:{adjustmentNonce:${adjustmentNonce}}) {
                    id
                    nft {
                        address
                        tokenId
                    }
                    ended
                    nonce
                    adjustmentNonce
                }
            }
        `
        request('https://api.thegraph.com/subgraphs/name/alcltzp/abacus-spot-graph-goerli-test', query).then(data => {
            data.auctions.forEach(element => {
                console.log(element.ended);
                adjustmentMap.set(adjustmentNonce, {
                    nft : element.nft.address,
                    id : element.nft.tokenId,
                    currentNonce : element.nonce,
                    complete : element.ended
                });
            });
        });
    }

    sub.on("SubCreated", async (_creator, _pool, _nonce, _tickets, _amounts, _lockTime, event) => {
        console.log(`
            New sub created! Here is the information:
            Owner: ${_creator}
            Pool: ${_pool}
            Nonce: ${_nonce}
            Tickets: ${_tickets} 
            Amounts: ${_amounts}
            Lock time: ${_lockTime}
        `);
        if(!activeNonces.includes(_nonce)) {
            activeNonces.push(_nonce);
            nonceMap.set(_nonce, {
                pendingPurchase: false,
                pendingAdjustment: false,
                pendingSale: false,
                tickets: _tickets,
                amounts: _amounts
            });
        }
    });

    sub.on("PurchaseExecuted", async (_creator, _pool, _nonce, _positionNonce, _startEpoch, _endEpoch, _gasPerPurchase, event) => {
        console.log(`
            New purchase executed! Here is the information:
            Owner: ${_creator}
            Pool: ${_pool}
            Nonce: ${_nonce}
            Position nonce: ${_positionNonce}
            StartEpoch: ${_startEpoch} 
            EndEpoch: ${_endEpoch}
            Gas spent: ${_gasPerPurchase}
        `);
        if(positionMap.get(parseInt(_nonce))) {
            let positionList = positionMap.get(parseInt(_nonce));
            positionList.push(parseInt(_positionNonce));
            positionMap.set(parseInt(_nonce), positionList);
        } else {
            let positionList = [parseInt(_positionNonce)];
            positionMap.set(parseInt(_nonce), positionList);
        }
    });

    sub.on("AdjustmentExecuted", async (_creator, _pool, _nonce, _positionNonce, _auctionNonce, _gasPerAdjustment, event) => {
        console.log(`
            New adjustment executed! Here is the information:
            Owner: ${_creator}
            Pool: ${_pool}
            Nonce: ${_nonce}
            PositionNonce: ${_positionNonce}
            AuctionNonce: ${_auctionNonce}
            Gas spent: ${_gasPerAdjustment}
        `);
    });

    sub.on("SaleExecuted", async (_creator, _pool, _nonce, _positionNonce, _payout, _lost, _gasPerSale, event) => {
        console.log(`
            New sale executed! Here is the information:
            Owner: ${_creator}
            Pool: ${_pool}
            Nonce: ${_nonce}
            PositionNonce: ${_positionNonce} 
            Payout: ${_payout}
            Lost: ${_lost}
            Gas spent: ${_gasPerSale}
        `);
        let activePositions = positionMap.get(parseInt(_nonce));
        removalIndex = activePositions.findIndex(item => {
            return item === parseInt(_positionNonce)
        });
        activePositions.splice(removalIndex, 1);
        positionMap.set(parseInt(_nonce), activePositions);
    });

    sub.on("SubCancelled", async (_creator, _pool, _nonce, event) => {
        console.log(`The sub with order nonce ${_nonce} has cancelled the subscription!`);
        cancelledMap.set(parseInt(_nonce), true);
    });

    updateBot();
    const subAdjustmentCheck = async (vault, manager, owner, orderNonce, positionNonce, adjustSubsidy) => {
        let adjustmentsMade = parseInt(await manager.adjustmentsMade(positionNonce));
        let adjustmentsRequired = parseInt(await vault.adjustmentsRequired());
        let gasBalance = await sub.gasStored(owner);
        if(adjustmentsMade !== adjustmentsRequired) {
            for(let i = adjustmentsMade; i < adjustmentsRequired; i++) {
                updateAdjustmentMap(i + 1);
                console.log(i + 1, adjustmentMap.get(i + 1));
                let currentNonce = adjustmentMap.get(i + 1).currentNonce;
                let complete = adjustmentMap.get(i + 1).complete;
                if(complete) {
                    if(
                        parseInt(adjustSubsidy) > parseInt(gasBalance)
                    ) {
                        console.log(`
                            Gas balance is not high enough to cover subsidy:
                            Subsidy: ${adjustSubsidy}
                            Balance: ${gasBalance}
                        `);
                        return;
                    }
                    let gasPrice = await provider.getGasPrice();
                    let functionGasFees = await sub.estimateGas.executeAdjustmentOrder(
                        deployer.address,
                        orderNonce,
                        positionNonce,
                        currentNonce
                    );
                    let finalPrice = gasPrice * functionGasFees;
                    console.log(`Estimated gas price: ${finalPrice}`);
                    if(finalPrice > 0.9 * adjustSubsidy) {
                        console.log(`
                            Gas subsidy is too low for execution:
                            Current price: ${finalPrice}
                            Subsidy (10% discount applied): ${0.9 * adjustSubsidy}
                        `);
                        return;
                    }
                    nonceMap.get(orderNonce).pendingAdjustment = true;
                    const adjust = await sub.executeAdjustmentOrder(
                        deployer.address,
                        orderNonce,
                        positionNonce,
                        currentNonce
                    )
                        .catch((error) => {
                            nonceMap.get(orderNonce).pendingAdjustment = false;
                            console.log("REVERTED:", error.reason);
                        })
                    adjust.wait()
                        .then(txHash => {
                            nonceMap.get(orderNonce).pendingAdjustment = false;
                            console.log(`Adjustment for position ${positionNonce} completed with hash ${txHash}`);
                        })
                        .catch(error => {
                            nonceMap.get(orderNonce).pendingAdjustment = false;
                            console.log("REVERTED:", error.reason);
                        });
                } else {
                    break;
                }
            }
        }
    }

    const subSaleCheck = async (vault, manager, owner, orderNonce, positionNonce, saleSubsidy) => {
        console.log("TIME TO SELL THIS BITCH");
        let adjustmentsMade = parseInt(await manager.adjustmentsMade(positionNonce));
        let adjustmentsRequired = parseInt(await vault.adjustmentsRequired());
        let gasBalance = await sub.gasStored(owner);
        if(adjustmentsMade === adjustmentsRequired) {
            if(
                parseInt(saleSubsidy) > parseInt(gasBalance)
            ) {
                console.log(`
                    Gas balance is not high enough to cover subsidy:
                    Subsidy: ${saleSubsidy}
                    Balance: ${gasBalance}
                `);
                return;
            }
            let gasPrice = await provider.getGasPrice();
            let functionGasFees = await sub.estimateGas.executeSellOrder(
                deployer.address,
                orderNonce,
                positionNonce
            );
            let finalPrice = gasPrice * functionGasFees;
            console.log(`Estimated gas price: ${finalPrice}`);
            if(finalPrice > 0.9 * saleSubsidy) {
                console.log(`
                    Gas subsidy is too low for execution:
                    Current price: ${finalPrice}
                    Subsidy (10% discount applied): ${0.9 * saleSubsidy}
                `);
                return;
            }
            nonceMap.get(orderNonce).pendingSale = true;
            const sell = await sub.executeSellOrder(
                deployer.address,
                orderNonce,
                positionNonce
            )
                .catch((error) => {
                    nonceMap.get(orderNonce).pendingSale = false;
                    console.log("REVERTED:", error.reason);
                })
            sell.wait()
                .then(txHash => {
                    nonceMap.get(orderNonce).pendingSale = false;
                    console.log(`Sale of position ${positionNonce} completed with hash ${txHash}`);
                })
                .catch(error => {
                    nonceMap.get(orderNonce).pendingSale = false;
                    console.log("REVERTED:", error.reason);
                });
        }
    }

    const subPurchaseCheck = async () => {
        // For loop to go through each nonce
        for(let i = 0; i < activeNonces.length; i++) {
            setTimeout(() => {
                1 + 1
            }, 10000);
            console.log(`=========== NEW ORDER ${activeNonces[i]} ===========`);
            if(cancelledMap.get(activeNonces[i])) {
                continue;
            }
            // Load nonce information regarding tx
            let order = await sub.orderList(activeNonces[i]);
            if(!order) {
                continue;
            }
            vault = await Vault.attach(order[1]);
            token = await MockToken.attach(await vault.token());
            manager = await Position.attach(await vault.positionManager());

            // Load nonce information regarding tx
            let pool = order[1];
            let owner = order[2];
            let tickets = nonceMap.get(activeNonces[i]).tickets;
            let amounts = nonceMap.get(activeNonces[i]).amounts;
            let cost = parseInt(order[5]);
            let lockTime = parseInt(order[6]);
            let purchaseSubsidy = parseInt(order[7]);
            let saleSubsidy = parseInt(order[8]);
            let adjustmentSubsidy = parseInt(order[9]);
            let orderDelay = parseInt(order[10]);
            let timeForNextTx = parseInt(order[11]);
            if(nonceMap.get(activeNonces[i]).pendingPurchase) {
                if(timeForNextTx === 0) {
                    timeForNextTx = (Date.now() / 1000);
                }
                timeForNextTx += orderDelay;
            }
            let currentEpoch = Math.floor(
                (Date.now() / 1000 - parseInt(await vault.startTime()))
                / parseInt(await vault.epochLength())
            );
            // Load nonce owner balances
            let gasBalance = await sub.gasStored(owner);
            let tokenBalance = await sub.tokensStored(owner, token.address);
            if(!gasBalance || !tokenBalance) {
                console.log(`Failed to load proper information! Moving on to the next order.`);
                continue;
            } else {
                console.log(`
                    Owner balances:
                    Gas: ${gasBalance}
                    Token: ${tokenBalance}
                `);
            }
            
            console.log("CHECKING CANCELLATION", cancelledMap.get(parseInt(activeNonces[i])));
            // Check that tx is valid by rules of the sub contract
            if(
                parseInt(Date.now() / 1000) < parseInt(timeForNextTx)
                || cancelledMap.get(parseInt(activeNonces[i]))
            ) {
                console.log(`
                    Purchase cooldown is not over:
                    Current time: ${Date.now() / 1000}
                    Earliest time: ${timeForNextTx}
                `);
                console.log(parseInt(activeNonces[i]), positionMap.get(parseInt(activeNonces[i])));
                if(positionMap.get(parseInt(activeNonces[i]))) {
                    let positionNonces = positionMap.get(parseInt(activeNonces[i]));
                    console.log(positionNonces);
                    for(let j = 0; j < positionNonces.length; j++) {
                        console.log(`Order nonce: ${parseInt(activeNonces[i])}, Position nonce: ${parseInt(positionNonces[j])}`);
                        let positionNonce = positionNonces[j];
                        let traderProfile = await manager.traderProfile(positionNonce);
                        let unlockEpoch = traderProfile[2];
                        let adjustmentsMade = await manager.adjustmentsMade(positionNonce);
                        let adjustmentsRequired = await vault.adjustmentsRequired();
                        console.log("Current epoch:", currentEpoch);
                        console.log("Unlock epoch:", unlockEpoch);
                        if(
                            parseInt(adjustmentsMade) === parseInt(adjustmentsRequired)
                        ) {
                            console.log(!nonceMap.get(activeNonces[i]).pendingSale);
                            if(
                                currentEpoch >= unlockEpoch
                                && !nonceMap.get(activeNonces[i]).pendingSale
                            ) {
                                console.log("Selling...");
                                subSaleCheck(vault, manager, owner, activeNonces[i], positionNonce, saleSubsidy);        
                            }
                        } else {
                            console.log("Adjusting...");
                            subAdjustmentCheck(vault, manager, owner, activeNonces[i], positionNonce, adjustmentSubsidy);
                        }
                        if(cancelledMap.get(parseInt(activeNonces[i]))) {
                            console.log(`Removing ${activeNonces[i]}`);
                            activeNonces.splice(i, 1);
                        }
                        continue;
                    }
                }
                continue;
            } else if(
                parseInt(cost) > parseInt(tokenBalance)
            ) {
                console.log(`
                    Token balance not high enough to cover cost:
                    Cost: ${cost}
                    Balance: ${tokenBalance}
                `);
                continue;
            } else if(
                parseInt(purchaseSubsidy) > parseInt(gasBalance)
            ) {
                console.log(`
                    Gas balance is not high enough to cover subsidy:
                    Subsidy: ${purchaseSubsidy}
                    Balance: ${gasBalance}
                `);
                continue;
            } else {
                console.log("Sub contract rules passed, moving to create order information!");
            }

            // Create remaining order information
            let epochLength = await vault.epochLength();
            let startEpoch = (Date.now() / 1000 - await vault.startTime()) / epochLength; 
            let endEpoch = ((parseInt(Date.now() / 1000) + parseInt(lockTime)) - await vault.startTime()) / epochLength;
            if(epochLength && startEpoch && endEpoch) {
                console.log(`
                    Lock length loaded:
                    Start epoch: ${startEpoch}
                    End epoch: ${endEpoch}
                `);
            }

            // Check that tx is valid by rules of the vault contract
            let watcherBool;
            for(let j = 0; j < tickets.length; j++) {
                if(watcherBool) {
                    break;
                }
                for(let k = startEpoch; k < endEpoch; k++) {
                    let ticketLimit = await vault.ticketLimit() * await vault.amountNft();
                    let existingInTicket = await vault.getTicketInfo(Math.floor(k), tickets[j]);
                    if(ticketLimit < parseInt(existingInTicket) + parseInt(amounts[j])) {
                        console.log(`
                            Order failed due to limit violation in ticket ${tickets[j]}:
                            Ticket limit: ${ticketLimit}
                            Existing volume: ${existingInTicket}
                            Purchase volume: ${amounts[j]}
                        `);
                        watcherBool = true;
                        break;
                    }
                }
            }
            if(watcherBool) {
                continue;
            }

            // Check that tx is valid based on the current gas v gas price offer
                // Estimated gas price must be <90% of total gas
            console.log(`Estimating order ${activeNonces[i]}`);
            let gasPrice = await provider.getGasPrice();
            let functionGasFees = await sub.estimateGas.executePurchaseOrder(
                deployer.address,
                activeNonces[i],
                tickets,
                amounts
            )
                .catch((error) => {
                    console.log("REVERTED:", error.reason);
                });
            if(!functionGasFees) {
                continue;
            }
            let finalPrice = gasPrice * functionGasFees;
            console.log(`Estimated gas price: ${finalPrice}`);
            if(finalPrice > 0.9 * purchaseSubsidy) {
                console.log(`
                    Gas subsidy is too low for execution:
                    Current price: ${finalPrice}
                    Subsidy (10% discount applied): ${0.9 * purchaseSubsidy}
                `);
                continue;
            }
            console.log(`Executing order ${activeNonces[i]}`);
            nonceMap.get(activeNonces[i]).pendingPurchase = true;
            const execute = await sub.executePurchaseOrder(
                deployer.address,
                activeNonces[i],
                tickets,
                amounts
            );
            execute.wait()
                .then(txHash => {
                    let found = false;
                    txHash.events.forEach(item => {
                        if(
                            item.eventSignature 
                            && item.eventSignature == 'PurchaseExecuted(address,address,uint256,uint256,uint256,uint256)'
                        ) {
                            console.log("FOUND IT!")
                            found = true;
                        }
                    });
                    if(found) {
                        console.log(`Order ${activeNonces[i]} completed with hash ${txHash}`);
                        nonceMap.get(activeNonces[i]).pendingPurchase = false;

                    }
                })
                .catch(error => {
                    nonceMap.get(activeNonces[i]).pendingPurchase = false;
                    console.log(`Order ${activeNonces[i]} failed`);
                    console.log("REVERTED:", error.reason);
                });
        }
        // Loop should tick once per 10 minutes
        console.log('-----------');
        console.log("Starting new cycle...");
        setTimeout(subPurchaseCheck, 20000);
    }
    subPurchaseCheck();
}

main();

// main()
//   .then(() => process.exit(0))
//   .catch((error) => {
//     console.error(error);
//     process.exit(1);
//   });
