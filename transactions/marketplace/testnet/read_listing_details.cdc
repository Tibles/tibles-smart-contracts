import MetadataViews from 0x631e88ae7f1d7c20
import NFTStorefront from 0x94b06cfca1d8a476
import NonFungibleToken from 0x631e88ae7f1d7c20
import TiblesNFT from 0xe93c412c964bdf40
import DrSeuss from 0xff68241f0f4fd521

pub struct PurchaseData {
  pub let id: UInt64
  pub let name: String?
  pub let amount: UFix64
  pub let description: String?
  pub let imageURL: String?

  init(id: UInt64, name: String?, amount: UFix64, description: String?, imageURL: String?) {
    self.id = id
    self.name = name
    self.amount = amount
    self.description = description
    self.imageURL = imageURL
  }
}

pub fun main(address: Address, listingResourceID: UInt64): PurchaseData {
  let account = getAccount(address)
  let marketCollectionRef = account.getCapability<&{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath)
    .borrow() ?? panic("Could not borrow market collection from address")

  let listing = marketCollectionRef.borrowListing(listingResourceID: listingResourceID)
    ?? panic("Listing with resource id does not exist: ".concat(listingResourceID.toString()))

  let listingDetails = listing.getDetails()

  let collection = account.getCapability(DrSeuss.PublicCollectionPath)
    .borrow<&{MetadataViews.ResolverCollection}>() ?? panic("Could not borrow a reference to the collection")

  let view = collection.borrowViewResolver(id: listingDetails.nftID)
  let display = view.resolveView(Type<MetadataViews.Display>())! as! MetadataViews.Display
  return PurchaseData(
    id: listingDetails.nftID,
    name: display.name,
    amount: listingDetails.salePrice,
    description: display.description,
    imageURL: display.thumbnail.uri(),
  )
}
