import Seussibles from 0x321d8fcde05f6e8c
import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import NFTStorefront from 0x4eb8a10cb9f87357
import TiblesNFT from 0x5cdeb067561defcb

transaction {
    prepare(acct: AuthAccount) {
        if acct.getCapability(Seussibles.PublicCollectionPath).borrow<&{TiblesNFT.CollectionPublic}>() == nil {
            acct.save(<- Seussibles.createEmptyCollection(), to: Seussibles.CollectionStoragePath)
            acct.link<&Seussibles.Collection{TiblesNFT.CollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(Seussibles.PublicCollectionPath, target: Seussibles.CollectionStoragePath)
        }

        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            acct.save(<- NFTStorefront.createStorefront(), to: NFTStorefront.StorefrontStoragePath)
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }
    }
}