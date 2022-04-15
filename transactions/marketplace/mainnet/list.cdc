import DapperUtilityCoin from 0xead892083b3e2c6c
import Seussibles from 0x321d8fcde05f6e8c
import FungibleToken from 0xf233dcee88fe0abe
import NFTStorefront from 0x4eb8a10cb9f87357
import NonFungibleToken from 0x1d7e57aa55817448
import TiblesNFT from 0x5cdeb067561defcb

transaction(itemNftID: UInt64, itemSalePrice: UFix64) {
    let nftProvider: Capability<&Seussibles.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let saleCuts: [NFTStorefront.SaleCut]

    prepare(tiblesAcct: AuthAccount, sellerAcct: AuthAccount) {
        assert(tiblesAcct.address == 0x61bce270cd80a7c2, message: "Listing requires authorizing signature")

        let marketAccount = getAccount(0x41d77346c4457f20)
        let marketFeePercent: UFix64 = 0.075
        let marketFee: UFix64 = itemSalePrice * marketFeePercent
        self.saleCuts = createSaleCuts(
            marketAccount: marketAccount,
            marketFee: marketFee,
            sellerAccount: getAccount(sellerAcct.address),
            sellerCut: itemSalePrice - marketFee
        )

        // If the account doesn't already have a Storefront create a new one for them
        if sellerAcct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            sellerAcct.save(<- NFTStorefront.createStorefront(), to: NFTStorefront.StorefrontStoragePath)
            sellerAcct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let SeussiblesNFTCollectionProviderPrivatePath = /private/SeussiblesNFTCollectionProviderForNFTStorefront
        if !sellerAcct.getCapability<&Seussibles.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(SeussiblesNFTCollectionProviderPrivatePath).check() {
            sellerAcct.link<&Seussibles.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(SeussiblesNFTCollectionProviderPrivatePath, target: Seussibles.CollectionStoragePath)
        }

        self.nftProvider = sellerAcct.getCapability<&Seussibles.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(SeussiblesNFTCollectionProviderPrivatePath)
        assert(self.nftProvider.borrow() != nil, message: "Missing or mis-typed Seussibles.Collection provider")

        self.storefront = sellerAcct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath)
            ?? panic("Missing or mis-typed NFTStorefront Storefront")

        let existingOffers = self.storefront.getListingIDs()
        for listingResourceID in existingOffers {
            let listing = self.storefront.borrowListing(listingResourceID: listingResourceID)!
            assert(
                listing.getDetails().nftID != itemNftID,
                message: "Listing for this NFT already exists, remove it before creating a new listing"
            )
        }
    }

    execute {
        var sumOfSaleCuts = 0.0 as UFix64
        for listing in self.saleCuts {
            sumOfSaleCuts = sumOfSaleCuts + listing.amount
        }
        assert(
            sumOfSaleCuts == itemSalePrice,
            message: "Sum of sale cuts: "
                .concat(sumOfSaleCuts.toString())
                .concat(", must be equal to item sale price: ")
                .concat(itemSalePrice.toString())
        )

        self.storefront.createListing(
            nftProviderCapability: self.nftProvider,
            nftType: Type<@Seussibles.NFT>(),
            nftID: itemNftID,
            salePaymentVaultType: Type<@DapperUtilityCoin.Vault>(),
            saleCuts: self.saleCuts
        )
    }
}

pub fun createSaleCuts(marketAccount: PublicAccount, marketFee: UFix64, sellerAccount: PublicAccount, sellerCut: UFix64): [NFTStorefront.SaleCut] {
    let marketDucReceiver = marketAccount.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
    assert(marketDucReceiver.borrow() != nil, message: "Missing or mis-typed DUC receiver")

    let sellerDucReceiver = sellerAccount.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver)
    assert(sellerDucReceiver.borrow() != nil, message: "Missing or mis-typed DUC receiver")

    return [
        NFTStorefront.SaleCut(receiver: marketDucReceiver, amount: marketFee),
        NFTStorefront.SaleCut(receiver: sellerDucReceiver, amount: sellerCut)
    ]
}