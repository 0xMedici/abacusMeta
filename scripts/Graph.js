const { request, gql } = require('graphql-request');
const { ethers } = require('hardhat');

function main() {
    let loanList = [];
    let loanTracker = new Map();
    let poolList = [];
    let poolTracker = new Map();
    const query = gql`
    {
        loans {
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
      
        auctions(where:{endTimestamp_gt:${0}}) {
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
        console.log(data);
        data.loans.forEach(element => {
            let nftInfo = element.nft.id.split('/');
            let grouping = nftInfo.join('/');
            console.log("GROUPING:", grouping);
            console.log("NEW:", {
                nft: nftInfo[0],
                id: nftInfo[1],
                pool: element.vault.id,
                amount: element.amount
            });
            loanTracker.set(grouping, {
                nft: nftInfo[0],
                id: nftInfo[1],
                pool: element.vault.id,
                amount: element.amount
            });
            loanList.push(grouping);
        });
        console.log(loanList);

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
        console.log(poolList);
    })
}

main();
