import DapperUtilityCoin from 0x82ec283f88a62e65
import DrSeuss from 0xff68241f0f4fd521
import FungibleToken from 0x9a0766d93b6608b7
import NFTStorefront from 0x94b06cfca1d8a476
import NonFungibleToken from 0x631e88ae7f1d7c20
import TiblesNFT from 0xe93c412c964bdf40

transaction(itemNftID: UInt64, itemSalePrice: UFix64) {
    let nftProvider: Capability<&DrSeuss.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>
    let storefront: &NFTStorefront.Storefront
    let saleCuts: [NFTStorefront.SaleCut]

    prepare(tiblesAcct: AuthAccount, sellerAcct: AuthAccount) {
        assert(tiblesAcct.address == 0x41dd4bcf04e15f6a, message: "Listing requires authorizing signature")

        let marketAccount = getAccount(0x77e55f65040a4207)
        let marketFeePercent: UFix64 = 0.08
        let marketFee: UFix64 = saleItemPrice * marketFeePercent
        self.saleCuts = createSaleCuts(
            marketAccount: marketAccount,
            marketFee: marketFee,
            sellerAccount: getAccount(sellerAcct.address),
            sellerCut: saleItemPrice - marketFee
        )

        // If the account doesn't already have a Storefront create a new one for them
        if sellerAcct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            sellerAcct.save(<- NFTStorefront.createStorefront(), to: NFTStorefront.StorefrontStoragePath)
            sellerAcct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }

        // We need a provider capability, but one is not provided by default so we create one if needed.
        let DrSeussNFTCollectionProviderPrivatePath = /private/DrSeussNFTCollectionProviderForNFTStorefront
        if !sellerAcct.getCapability<&DrSeuss.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(DrSeussNFTCollectionProviderPrivatePath).check() {
            sellerAcct.link<&DrSeuss.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(DrSeussNFTCollectionProviderPrivatePath, target: DrSeuss.CollectionStoragePath)
        }

        self.nftProvider = sellerAcct.getCapability<&DrSeuss.Collection{NonFungibleToken.Provider, NonFungibleToken.CollectionPublic}>(DrSeussNFTCollectionProviderPrivatePath)
        assert(self.nftProvider.borrow() != nil, message: "Missing or mis-typed DrSeuss.Collection provider")

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
            nftType: Type<@DrSeuss.NFT>(),
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
