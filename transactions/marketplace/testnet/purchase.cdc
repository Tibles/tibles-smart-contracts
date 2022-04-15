import DapperUtilityCoin from 0x82ec283f88a62e65
import DrSeuss from 0xff68241f0f4fd521
import FungibleToken from 0x9a0766d93b6608b7
import NFTStorefront from 0x94b06cfca1d8a476
import NonFungibleToken from 0x631e88ae7f1d7c20
import TiblesNFT from 0xe93c412c964bdf40

transaction(listingResourceID: UInt64, storefrontAddress: Address, expectedPrice: UFix64) {
    let paymentVault: @FungibleToken.Vault
    let buyerDrSeussCollection: &{TiblesNFT.CollectionPublic}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let balanceBeforeTransfer: UFix64
    let mainDucVault: &DapperUtilityCoin.Vault

    prepare(dapper: AuthAccount, buyer: AuthAccount) {
        // Initialize the buyer's account if it is not already initialized
        if buyer.borrow<&DrSeuss.Collection>(from: DrSeuss.CollectionStoragePath) == nil {
            buyer.save(<-DrSeuss.createEmptyCollection(), to: DrSeuss.CollectionStoragePath)

            buyer.link<&DrSeuss.Collection{TiblesNFT.CollectionPublic, NonFungibleToken.Receiver}>(
                DrSeuss.PublicCollectionPath,
                target: DrSeuss.CollectionStoragePath
            )
        }

        // Fetch the storefront where the listing exists
        self.storefront = getAccount(storefrontAddress)
            .getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(
                NFTStorefront.StorefrontPublicPath
            )
            .borrow()
            ?? panic("Could not borrow Storefront from provided address")

        // Fetch the listing from the storefront by ID
        self.listing = self.storefront.borrowListing(listingResourceID: listingResourceID)
            ?? panic("No Offer with that ID in Storefront")

        // Get access to Dapper's DUC vault
        let salePrice = self.listing.getDetails().salePrice
        self.mainDucVault = dapper.borrow<&DapperUtilityCoin.Vault>(from: /storage/dapperUtilityCoinVault)
            ?? panic("Cannot borrow DapperUtilityCoin vault from dapper storage")

        // Withdraw the appropriate amount of DUC from the vault
        self.balanceBeforeTransfer = self.mainDucVault.balance
        self.paymentVault <- self.mainDucVault.withdraw(amount: salePrice)

        // Check that the price is what we expect
        if (expectedPrice != salePrice) {
            panic("Expected price does not match sale price")
        }

        self.buyerDrSeussCollection = buyer
            .getCapability<&{TiblesNFT.CollectionPublic}>(DrSeuss.PublicCollectionPath)
            .borrow()
            ?? panic("Could not borrow DrSeuss Collection from provided address")
    }

    execute {
        let tible <- self.listing.purchase(
            payment: <-self.paymentVault
        ) as! @DrSeuss.NFT

        self.buyerDrSeussCollection.depositTible(tible: <- tible)
    }

    post {
        // Ensure there is no DUC leakage
        self.mainDucVault.balance == self.balanceBeforeTransfer: "transaction would leak DUC"
    }
}
