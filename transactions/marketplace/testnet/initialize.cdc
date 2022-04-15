import DrSeuss from 0xff68241f0f4fd521
import MetadataViews from 0x631e88ae7f1d7c20
import NonFungibleToken from 0x631e88ae7f1d7c20
import NFTStorefront from 0x94b06cfca1d8a476
import TiblesNFT from 0xe93c412c964bdf40

transaction {
    prepare(acct: AuthAccount) {
        if acct.getCapability(DrSeuss.PublicCollectionPath).borrow<&{TiblesNFT.CollectionPublic}>() == nil {
            acct.save(<- DrSeuss.createEmptyCollection(), to: DrSeuss.CollectionStoragePath)
            acct.link<&DrSeuss.Collection{TiblesNFT.CollectionPublic, NonFungibleToken.CollectionPublic, MetadataViews.ResolverCollection}>(DrSeuss.PublicCollectionPath, target: DrSeuss.CollectionStoragePath)
        }

        if acct.borrow<&NFTStorefront.Storefront>(from: NFTStorefront.StorefrontStoragePath) == nil {
            acct.save(<- NFTStorefront.createStorefront(), to: NFTStorefront.StorefrontStoragePath)
            acct.link<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath, target: NFTStorefront.StorefrontStoragePath)
        }
    }
}