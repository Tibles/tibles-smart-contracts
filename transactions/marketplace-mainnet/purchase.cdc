import DapperUtilityCoin from 0xead892083b3e2c6c
import Seussibles from 0x321d8fcde05f6e8c
import FungibleToken from 0xf233dcee88fe0abe
import NFTStorefront from 0x4eb8a10cb9f87357
import NonFungibleToken from 0x1d7e57aa55817448
import TiblesNFT from 0x5cdeb067561defcb

transaction(listingResourceID: UInt64, storefrontAddress: Address, expectedPrice: UFix64) {
    let paymentVault: @FungibleToken.Vault
    let buyerSeussiblesCollection: &{TiblesNFT.CollectionPublic}
    let storefront: &NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}
    let listing: &NFTStorefront.Listing{NFTStorefront.ListingPublic}
    let balanceBeforeTransfer: UFix64
    let mainDucVault: &DapperUtilityCoin.Vault

    prepare(dapper: AuthAccount, buyer: AuthAccount) {
        // Initialize the buyer's account if it is not already initialized
        if buyer.borrow<&Seussibles.Collection>(from: Seussibles.CollectionStoragePath) == nil {
            buyer.save(<-Seussibles.createEmptyCollection(), to: Seussibles.CollectionStoragePath)

            buyer.link<&Seussibles.Collection{TiblesNFT.CollectionPublic, NonFungibleToken.Receiver}>(
                Seussibles.PublicCollectionPath,
                target: Seussibles.CollectionStoragePath
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

        self.buyerSeussiblesCollection = buyer
            .getCapability<&{TiblesNFT.CollectionPublic}>(Seussibles.PublicCollectionPath)
            .borrow()
            ?? panic("Could not borrow Seussibles Collection from provided address")
    }

    execute {
        let tible <- self.listing.purchase(
            payment: <-self.paymentVault
        ) as! @Seussibles.NFT

        self.buyerSeussiblesCollection.depositTible(tible: <- tible)
    }

    post {
        // Ensure there is no DUC leakage
        self.mainDucVault.balance == self.balanceBeforeTransfer: "transaction would leak DUC"
    }
}
