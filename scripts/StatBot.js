const { ADDRESSES } = require('./Addresses.js');

async function main() {
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
    });

    lend.on("InterestPaid", async (_user,_pool,nft,id,_epoch,_amountPaid, event) => {
        console.log(`${user} has paid ${_amountPaid} to cover interest payments for a loan against ${nft} ${id}`);
    });

    lend.on("EthRepayed", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_amount} ETH repaid by ${_user} in relation to a loan taken against pool at address ${_pool} using ${nft} ${id}`);
        
    });

    lend.on("BorrowerLiquidated", async (_user,_pool,nft,id,_amount,event) => {
        console.log(`${_user} liquidated on a loan taken against pool at address ${_pool}. Auction starting for ${nft} ${id}`);
    });

    lend.on("LoanTransferred", async (_pool,from,to,nft,id,event) => {
        console.log(`Loan on ${nft} ${id} has been transferred from ${from} to ${to}`);
    });

    factory.on("VaultCreated", (name,_creator,_pool,event) => {
        console.log(`New Spot pool ${name} created by ${_creator} at ${_pool}`);
    });

    factory.on("NftInclusion", (_pool,nfts,event) => {
        console.log(`New set of NFTs included in pool ${_pool}: ${nfts}`);
    });

    factory.on("VaultBegun", (_pool,_collateralSlots,_ticketSize,_interest,_epoch,event) => {
        console.log(`Spot pool begun at ${_pool} with ${_collateralSlots} and tranche size of ${_ticketSize / 1000} with a desired interest rate of ${_interest} and epoch length of ${_epoch}`);
    });

    factory.on("Purchase", (_pool,_buyer,tickets,amountPerTicket,nonce,startEpoch,finalEpoch,event) => {
        console.log(`New appraisal submitted at ${_pool} by ${_buyer} in tranches ${tickets} with amounts of ${amountPerTicket} and an unlock epoch of ${finalEpoch}`);
    });

    factory.on("SaleComplete", (_pool,_seller,nonce,ticketsSold,creditsPurchased,event) => {
        console.log(`${_seller} sold position in ${_pool}`);
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
    });

    factory.on("AuctionEnded", async (_pool,_closePoolContract,_collection,_id,_winner,_highestBid, event) => {
        console.log(`Auction for ${_collection} ${_id} ended with a winning bid of ${_highestBid} submitted by ${_winner}!`);
    });

    factory.on("PrincipalCalculated", (_pool,_closePoolContract,_collection,_id,_user,_nonce,_closureNonce,event) => {
        console.log(`Position adjusted in ${_pool} by ${_user} for ${_collection} ${_id} with a closure nonce of ${_closureNonce}`);
    });
}

main();