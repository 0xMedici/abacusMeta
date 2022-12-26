//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVault {

    function initialize(
        string memory _name,
        address _controller,
        address _creator,
        address _positionManager
    ) external;

    /// @notice [setup phase] Give an NFT access to the pool 
    /// @param _compTokenInfo Compressed list of NFT collection address and token ID information
    function includeNft(uint256[] calldata _compTokenInfo) external;

    /// @notice [setup phase] Start the pools operation
    /// @param _slots The amount of collateral slots the pool will offer
    /// @param _ticketSize The size of a tranche
    /// @param _rate The chosen interest rate
    /// @param _token the token denomination of the pool
    /// @param _riskBase starting value used for risk point calculations
    /// @param _riskStep marginal step used for risk point calculation
    /// @param _creatorFee fee the creator receives from fees generated
    /// @param _liquidationRule liquidation rule regarding interest payments missed
    function begin(
        uint32 _slots, 
        uint256 _ticketSize, 
        uint256 _rate,
        uint256 _epochLength,
        address _token,
        uint256 _riskBase,
        uint256 _riskStep,
        uint256 _creatorFee,
        uint256 _liquidationRule
    ) external;

    /// @notice Purchase an appraisal position in a spot pool
    /// @dev Each position that is held by a user is tagged by a nonce which allows each 
    /// position to hold the property of a pseudo non-fungible token (psuedo because it 
    /// doesn't directly follow the common ERC721 token standard). This position is tradeable
    /// post-purchase via the 'transferFrom' function. 
    /// @param _buyer The position buyer
    /// @param tickets Array of tickets that the buyer would like to add in their position
    /// @param amountPerTicket Array of amount of tokens that the buyer would like to purchase
    /// from each ticket
    /// @param startEpoch Starting LP epoch
    /// @param finalEpoch The first epoch during which the LP position unlocks
    function purchase(
        address _buyer,
        uint256[] calldata tickets, 
        uint256[] calldata amountPerTicket,
        uint32 startEpoch,
        uint32 finalEpoch
    ) external;

    /// @notice Sell an appraisal position to receive remaining principal and interest/fees earned
    /// @dev Users ticket balances are counted on a risk adjusted basis in comparison to the
    /// maximum purchased ticket tranche. The risk adjustment per ticket is based on the risk 
    /// base and risk step chosen by the pool creator.
    /// @param _user Address of the appraise
    /// @param _nonce Held nonce to close 
    function sell(
        address _user,
        uint256 _nonce
    ) external returns(uint256 interestEarned);

    /// @notice Allow another user permission to execute a single 'transferFrom' call
    /// @param recipient Allowee address
    function changeTransferPermission(
        address recipient
    ) external returns(bool);

    /// @notice Transfer a position or portion of a position from one user to another
    /// @dev A user can transfer an amount of tokens in each tranche from their held position at
    /// 'nonce' to another users new position (upon transfer a new position (with a new nonce)
    /// is created for the 'to' address). 
    /// @param from Sender 
    /// @param to Recipient
    /// @param nonce Nonce of position that transfer is being applied
    function transferFrom(
        address from,
        address to,
        uint256 nonce
    ) external returns(bool);

    /// @notice Close an NFT in exchange for the 'payoutPerRes' of the current epoch
    /// @dev This closure triggers an auction to begin in which the closed NFT will be sold
    /// and can only be called by the holder of the NFT. Upon calling this function the caller will
    /// be sent the 'payoutPerRes' and the NFT will be taken. (If this is the first function call)
    /// it will create a close pool contract that the rest of the closure will use as well.
    /// @param _nft NFT that is being closed
    /// @param _id Token ID of the NFT that is being closed
    function closeNft(address _nft, uint256 _id) external returns(uint256);

    /// @notice Registers the final auction sale value in the pool.
    /// @dev Called automagically by the closure contract 
    /// @param _nft NFT that was auctioned off
    /// @param _id Token ID of the NFT that was auctioned off
    /// @param _saleValue Auction sale value
    function updateSaleValue(
        address _nft,
        uint256 _id,
        uint256 _saleValue
    ) external;

    /// @notice Used to replenish total available collateral slots in a pool after a set of losing closures.
    function restore() external;

    /// @notice Adjust a users appraisal information after an NFT is closed
    /// @dev This function checks an appraisers accuracy and is responsible for slashing
    /// or rewarding them based on their accuracy in their appraisal. 
    /// @param _user Address of the appraise owner
    /// @param _nonce Nonce of the appraisal
    /// @param _nft Address of the auctioned NFT
    /// @param _id Token ID of the auctioned NFT
    /// @param _closureNonce Closure nonce of the NFT being adjusted for
    function adjustTicketInfo(
        address _user,
        uint256 _nonce,
        address _nft,
        uint256 _id,
        uint256 _closureNonce
    ) external returns(bool);

    /// @notice Receive and process an fees earned by the Spot pool
    function processFees(uint256 _amount) external;

    /// @notice Send liquidity to borrower
    function accessLiq(address _user, address _nft, uint256 _id, uint256 _amount) external;

    /// @notice Receive liquidity from lending contract
    function depositLiq(address _nft, uint256 _id, uint256 _amount) external;

    /// @notice Resets outstanding liquidity in the case of a `purchase` liquidation
    function resetOutstanding(address _nft, uint256 _id) external;

    /// @notice Returns the current amount of usable collateral slots. 
    function getReservationsAvailable() external view returns(uint256);

    /// @notice Returns the total available funds during an `_epoch`
    function getTotalAvailableFunds(uint256 _epoch) external view returns(uint256);

    /// @notice Returns the payout per reservations during an `_epoch`
    function getPayoutPerReservation(uint256 _epoch) external view returns(uint256);

    /// @notice Returns the total amount of risk points outstanding in an `_epoch`
    function getRiskPoints(uint256 _epoch) external view returns(uint256);

    /// @notice Returns total amount of tokens purchased during an `_epoch`
    function getTokensPurchased(uint256 _epoch) external view returns(uint256);

    /// @notice Get the list of NFT address and corresponding token IDs in by this pool
    function getHeldTokenExistence(address _nft, uint256 _id) external view returns(bool);

    /// @notice Get the amount of spots in a ticket that have been purchased during an epoch
    function getTicketInfo(uint256 epoch, uint256 ticket) external view returns(uint256);
}