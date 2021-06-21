// OneShots.cdc

import NonFungibleToken from "NonFungibleToken.cdc"
import TiblesNFT from "TiblesNFT.cdc"
import TiblesApp from "TiblesApp.cdc"
import TiblesProducer from "TiblesProducer.cdc"

pub contract OneShots:
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

  pub resource NFT: NonFungibleToken.INFT, TiblesNFT.INFT {
    pub let id: UInt64
    pub let mintNumber: UInt32

    priv let contentCapability: Capability
    priv let contentId: String

    init(id: UInt64, mintNumber: UInt32, contentCapability: Capability, contentId: String) {
      self.id = id
      self.mintNumber = mintNumber
      self.contentId = contentId
      self.contentCapability = contentCapability
    }
    
    pub fun metadata(): {String: AnyStruct}? {
      let content = self.contentCapability.borrow<&AnyStruct{TiblesProducer.IContent}>()!
      return content.getMetadata(contentId: self.contentId)
    }
  }

  pub resource Collection:
    NonFungibleToken.Provider,
    NonFungibleToken.Receiver,
    NonFungibleToken.CollectionPublic,
    TiblesNFT.CollectionPublic
  {
    pub var ownedNFTs: @{UInt64: NonFungibleToken.NFT}

    pub fun deposit(token: @NonFungibleToken.NFT) {
      let tible <- token as! @OneShots.NFT
      self.depositTible(tible: <- tible)
    }

    pub fun depositTible(tible: @AnyResource{TiblesNFT.INFT}) {
      pre {
        self.ownedNFTs[tible.id] == nil: "Tible with this id already exists"
      }
      let token <- tible as! @OneShots.NFT
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
      return ref as! &OneShots.NFT
    }
  
    pub fun withdraw(withdrawID: UInt64): @NonFungibleToken.NFT {
      let token <- self.ownedNFTs.remove(key: withdrawID) ?? panic("Cannot withdraw: tible does not exist in the collection")
      emit Withdraw(id: token.id, from: self.owner?.address)
      return <-token
    }

    pub fun withdrawTible(id: UInt64): @AnyResource{TiblesNFT.INFT} {
      let token <- self.ownedNFTs.remove(key: id) ?? panic("Cannot withdraw: tible does not exist in the collection")
      let tible <- token as! @OneShots.NFT
      emit Withdraw(id: tible.id, from: self.owner?.address)
      return <-tible
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

  pub resource Producer: TiblesProducer.IProducer, TiblesProducer.IContent {
    pub let minters: @{String: TiblesProducer.Minter}
    pub var contentIdsToPaths: {String: TiblesProducer.ContentLocation}
    pub let sets: {String: Set}

    pub fun minter(id: String): &Minter? {
      let ref = &self.minters[id] as auth &AnyResource{TiblesProducer.IMinter}
      let minter = ref as! &Minter
      return minter
    }

    pub fun set(id: String): &Set? {
      return &self.sets[id] as? &Set
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

    pub fun updateSet(_ set: Set) {
      self.sets[set.id] = set
    }

    pub fun getMetadata(contentId: String): {String: AnyStruct}? {
      if self.contentIdsToPaths[contentId] == nil {
        return nil
      }

      let path = self.contentIdsToPaths[contentId] as! ContentLocation
      if self.set(id: path.setId) == nil {
        panic("The set does not exist!")
      }

      let set = self.set(id: path.setId)!
      if set.item(path.itemId) == nil {
        panic("The item does not exist!")
      }

      let item = set.item(path.itemId)!
      let variant = set.variant(path.variantId)
      var metadata: {String: AnyStruct} = {}
      metadata["set"] = set.metadata
      metadata["item"] = item.metadata
      metadata["variant"] = variant?.metadata
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
    pub let items: {String: Item}
    pub let variants: {String: Variant}
    pub var metadata: {String: AnyStruct}?

    access(account) fun setMetadata(metadata: {String: AnyStruct}?) {
      self.metadata = metadata
    }

    pub fun item(_ id: String): Item? {
      return self.items[id]
    }

    pub fun addItem(_ newItem: Item) {
      pre {
        self.items[newItem.id] == nil: "There is already an item with that ID."
      }
      self.items[newItem.id] = newItem
    }

    pub fun variant(_ id: String): Variant? {
      return self.variants[id]
    }

    pub fun addVariant(_ newVariant: Variant) {
      pre {
        self.variants[newVariant.id] == nil: "There is already a variant with that ID."
      }
      self.variants[newVariant.id] = newVariant
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
    pub var metadata: {String: AnyStruct}?

    priv fun setMetadata(metadata: {String: AnyStruct}?) {
      self.metadata = metadata
    }

    init(id: String) {
      self.id = id
      self.metadata = nil
    }
  }

  pub struct Variant {
    pub let id: String
    pub var metadata: {String: AnyStruct}?
  
    priv fun setMetadata(metadata: {String: AnyStruct}?) {
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
    pub let tibles: @{UInt32: AnyResource{TiblesNFT.INFT}}
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

      let id = OneShots.totalSupply + (1 as UInt64)
      let mintNumber = self.lastMintNumber + (1 as UInt32)
      let tible <- create NFT(id: id, mintNumber: mintNumber, contentCapability: self.contentCapability, contentId: self.id)
      self.tibles[mintNumber] <-! tible
      self.lastMintNumber = mintNumber
      OneShots.totalSupply = id

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

    self.appId = "com.tibles.oneshots"
    self.title = "One Shots"
    self.description = "Comic book themed collectibles."

    self.ProducerStoragePath = /storage/TiblesOneShotsProducer
    self.ProducerPath = /private/TiblesOneShotsProducer
    self.ContentPath = /public/TiblesOneShotsContent
    self.CollectionStoragePath = /storage/TiblesOneShotsCollection
    self.PublicCollectionPath = /public/TiblesOneShotsCollection

    let producer <- create Producer()
    self.account.save<@Producer>(<-producer, to: self.ProducerStoragePath)
    self.account.link<&Producer>(self.ProducerPath, target: self.ProducerStoragePath)

    self.account.link<&AnyResource{TiblesProducer.IContent}>(self.ContentPath, target: self.ProducerStoragePath)
    self.contentCapability = self.account.getCapability(self.ContentPath)

    emit ContractInitialized()
  }
}
