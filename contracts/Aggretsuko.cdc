import MetadataViews from 0x1d7e57aa55817448
import NonFungibleToken from 0x1d7e57aa55817448
import TiblesApp from 0x5cdeb067561defcb
import TiblesNFT from 0x5cdeb067561defcb
import TiblesProducer from 0x5cdeb067561defcb

pub contract Aggretsuko:
  NonFungibleToken,
  TiblesApp,
  TiblesNFT,
  TiblesProducer
{
  pub let appId: String
  pub let title: String
  pub let description: String
  pub let ProducerStoragePath: StoragePath
  pub let ProducerPath: PrivatePath
  pub let ContentPath: PublicPath
  pub let contentCapability: Capability
  pub let CollectionStoragePath: StoragePath
  pub let PublicCollectionPath: PublicPath

  pub event ContractInitialized()
  pub event Withdraw(id: UInt64, from: Address?)
  pub event Deposit(id: UInt64, to: Address?)
  pub event MinterCreated(minterId: String)
  pub event TibleMinted(minterId: String, mintNumber: UInt32, id: UInt64)

  pub var totalSupply: UInt64

  pub resource NFT: NonFungibleToken.INFT, TiblesNFT.INFT, MetadataViews.Resolver {
    pub let id: UInt64
    pub let mintNumber: UInt32

    access(self) let contentCapability: Capability
    access(self) let contentId: String

    init(id: UInt64, mintNumber: UInt32, contentCapability: Capability, contentId: String) {
      self.id = id
      self.mintNumber = mintNumber
      self.contentId = contentId
      self.contentCapability = contentCapability
    }
    
    pub fun metadata(): {String:AnyStruct}? {
      let content = self.contentCapability.borrow<&{TiblesProducer.IContent}>() ?? panic("Failed to borrow content provider")
      return content.getMetadata(contentId: self.contentId)
    }

    pub fun display(): MetadataViews.Display {
      let data = self.metadata() ?? panic("Missing NFT metadata")
      let item = data["item"]! as! {String: AnyStruct}
      let title = item["title"]! as! String
      let imageUrl = item["imageUrl"]! as! String
      return MetadataViews.Display(
        name: title,
        description: "#".concat(self.mintNumber.toString()),
        thumbnail: MetadataViews.HTTPFile(url: imageUrl)
      )
    }

    pub fun getViews(): [Type] {
      return [Type<MetadataViews.Display>()]
    }

    pub fun resolveView(_ view: Type): AnyStruct? {
      switch view {
        case Type<MetadataViews.Display>(): return self.display()
        default: return nil
      }
    }
  }

  pub resource Collection:
    NonFungibleToken.Provider,
    NonFungibleToken.Receiver,
    NonFungibleToken.CollectionPublic,
    TiblesNFT.CollectionPublic,
    MetadataViews.ResolverCollection
  {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let tible <- token as! @Aggretsuko.NFT
      self.depositTible(tible: <- tible)
    }

    pub fun depositTible(tible: @AnyResource{TiblesNFT.INFT}) {
      pre {
        self.ownedNFTs[tible.id] == nil: "tible with this id already exists"
      }
      let token <- tible as! @Aggretsuko.NFT
      let id = token.id
      self.ownedNFTs[id] <-! token

      if self.owner?.address != nil {
        emit Deposit(id: id, to: self.owner?.address)
      }
    }

    pub fun getIDs(): [UInt64] {
      return self.ownedNFTs.keys
    }

    pub fun borrowNFT(id: UInt64): &NonFungibleToken.NFT {
      return &self.ownedNFTs[id] as &NonFungibleToken.NFT
    }

    pub fun borrowTible(id: UInt64): &AnyResource{TiblesNFT.INFT} {
      let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
      return ref as! &Aggretsuko.NFT
    }
  
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: tible does not exist in the collection")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun withdrawTible(id: UInt64): @AnyResource{TiblesNFT.INFT} {
      let token <- self.ownedNFTs.remove(key: id) ?? panic("Cannot withdraw: tible does not exist in the collection")
      let tible <- token as! @Aggretsuko.NFT
      emit Withdraw(id: tible.id, from: self.owner?.address)
      return <-tible
    }
    
    pub fun borrowViewResolver(id: UInt64): &{MetadataViews.Resolver} {
      let nft = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
      let tible = nft as! &Aggretsuko.NFT
      return tible
    }

    pub fun tibleDescriptions(): {UInt64: {String: AnyStruct}} {
      var descriptions: {UInt64: {String: AnyStruct}} = {}

      for id in self.ownedNFTs.keys {
        let ref = &self.ownedNFTs[id] as auth &NonFungibleToken.NFT
        let nft = ref as! &NFT
        var description: {String: AnyStruct} = {}
        description["mintNumber"] = nft.mintNumber
        description["metadata"] = nft.metadata()
        descriptions[id] = description
      }

      return descriptions
    }

    init () {
      self.ownedNFTs <- {}
    }

    destroy() {
      destroy self.ownedNFTs
    }
  }

  pub fun createEmptyCollection(): @NonFungibleToken.Collection {
    return <- create Collection()
  }

  pub struct ContentLocation {
    pub let setId: String
    pub let itemId: String
    pub let variantId: String
  
    init(setId: String, itemId: String, variantId: String) {
      self.setId = setId
      self.itemId = itemId
      self.variantId = variantId
    }
  }
  
  pub struct interface IContentLocation {}

  pub resource Producer: TiblesProducer.IProducer, TiblesProducer.IContent {
    access(contract) let minters: @{String: TiblesProducer.Minter}
    access(contract) let contentIdsToPaths: {String: TiblesProducer.ContentLocation}
    access(contract) let sets: {String: Set}

    pub fun minter(id: String): &Minter? {
      let ref = &self.minters[id] as auth &AnyResource{TiblesProducer.IMinter}
      let minter = ref as! &Minter
      return minter
    }

    pub fun set(id: String): &Set? {
      if self.sets[id] != nil {
        return &self.sets[id] as &Set
      } else {
        return nil
      }
    }

    pub fun addSet(_ set: Set, contentCapability: Capability) {
      self.sets[set.id] = set

      for item in set.items.values {
        for variant in set.variants.values {
          var limit: UInt32? = nil
          if let variantMetadata = variant.metadata {
            limit = variantMetadata["countMax"] as? UInt32
          }

          let minterId: String = set.id.concat(":").concat(item.id).concat(":").concat(variant.id)
          let minter <- create Minter(id: minterId, limit: limit, contentCapability: contentCapability)

          if self.minters.keys.contains(minterId) {
              panic("Minter ID ".concat(minterId).concat(" already exists."))
          }

          self.minters[minterId] <-! minter

          let path = ContentLocation(setId: set.id, itemId: item.id, variantId: variant.id)
          self.contentIdsToPaths[minterId] = path

          emit MinterCreated(minterId: minterId)
        }
      }
    }

    pub fun getMetadata(contentId: String): {String: AnyStruct}? {
      let path = self.contentIdsToPaths[contentId] ?? panic("Failed to get content path")
      let location = path as! ContentLocation
      let set = self.set(id: location.setId) ?? panic("The set does not exist!")
      let item = set.item(location.itemId) ?? panic("The item does not exist!")
      let variant = set.variant(location.variantId) ?? panic("The variant does not exist!")

      var metadata: {String:AnyStruct} = {}
      metadata["set"] = set.metadata
      metadata["item"] = item.metadata
      metadata["variant"] = variant.metadata
      return metadata
    }

    init() {
      self.sets = {}
      self.contentIdsToPaths = {}
      self.minters <- {}
    }

    destroy() {
      destroy self.minters
    }
  }
  
  pub struct Set {
    pub let id: String
    access(contract) let items: {String: Item}
    access(contract) let variants: {String: Variant}
    access(contract) var metadata: {String: AnyStruct}?

    pub fun setMetadata(metadata: {String:AnyStruct}?) {
      self.metadata = metadata
    }

    pub fun item(_ id: String): &Item? {
      if self.items[id] != nil {
        return &self.items[id] as &Item
      } else {
        return nil
      }
    }

    pub fun variant(_ id: String): &Variant? {
      if self.variants[id] != nil {
        return &self.variants[id] as &Variant
      } else {
        return nil
      }
    }

    init(id: String) {
      self.id = id
      self.items = {}
      self.variants = {}
      self.metadata = nil
    }
  }

  pub struct Item {
    pub let id: String
    access(contract) var metadata: {String:AnyStruct}?

    pub fun setMetadata(metadata: {String:AnyStruct}?) {
      self.metadata = metadata
    }

    init(id: String) {
      self.id = id
      self.metadata = nil
    }
  }

  pub struct Variant {
    pub let id: String
    access(contract) var metadata: {String:AnyStruct}?
  
    pub fun setMetadata(metadata: {String:AnyStruct}?) {
      self.metadata = metadata
    }

    init(id: String) {
      self.id = id
      self.metadata = nil
    }
  }

  pub resource Minter: TiblesProducer.IMinter {
    pub let id: String
    pub var lastMintNumber: UInt32
    access(contract) let tibles: @{UInt32: AnyResource{TiblesNFT.INFT}}
    pub let limit: UInt32?
    pub let contentCapability: Capability

    pub fun withdraw(mintNumber: UInt32): @AnyResource{TiblesNFT.INFT} {
      pre {
        self.tibles[mintNumber] != nil: "The tible does not exist in this minter."
      }
      return <- self.tibles.remove(key: mintNumber)!
    }

    pub fun mintNext() {
      if let limit = self.limit {
        if self.lastMintNumber >= limit {
          panic("You've hit the limit for number of tokens in this minter!")
        }
      }

      let id = Aggretsuko.totalSupply + 1
      let mintNumber = self.lastMintNumber + 1
      let tible <- create NFT(id: id, mintNumber: mintNumber, contentCapability: self.contentCapability, contentId: self.id)
      self.tibles[mintNumber] <-! tible
      self.lastMintNumber = mintNumber
      Aggretsuko.totalSupply = id

      emit TibleMinted(minterId: self.id, mintNumber: mintNumber, id: id)
    }

    init(id: String, limit: UInt32?, contentCapability: Capability) {
      self.id = id
      self.lastMintNumber = 0
      self.tibles <- {}
      self.limit = limit
      self.contentCapability = contentCapability
    }
  
    destroy() {
      destroy self.tibles
    }
  }

  init() {
    self.totalSupply = 0

    self.appId = "com.tibles.aggretusko"
    self.title = "Aggretusko"
    self.description = "Aggretsuko officially licensed NFTs"

    self.ProducerStoragePath = /storage/TiblesAggretsukoProducer
    self.ProducerPath = /private/TiblesAggretsukoProducer
    self.ContentPath = /public/TiblesAggretsukoContent
    self.CollectionStoragePath = /storage/TiblesAggretsukoCollection
    self.PublicCollectionPath = /public/TiblesAggretsukoCollection

    let producer <- create Producer()
    self.account.save<@Producer>(<-producer, to: self.ProducerStoragePath)
    self.account.link<&Producer>(self.ProducerPath, target: self.ProducerStoragePath)

    self.account.link<&{TiblesProducer.IContent}>(self.ContentPath, target: self.ProducerStoragePath)
    self.contentCapability = self.account.getCapability(self.ContentPath)

    emit ContractInitialized()
  }
}
