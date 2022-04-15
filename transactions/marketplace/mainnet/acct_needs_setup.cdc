import DapperUtilityCoin from 0xead892083b3e2c6c
import FungibleToken from 0xf233dcee88fe0abe
import NFTStorefront from 0x4eb8a10cb9f87357
import NonFungibleToken from 0x1d7e57aa55817448
import TiblesNFT from 0x5cdeb067561defcb
import Seussibles from 0x321d8fcde05f6e8c

pub fun main(address: Address): Bool {
  let acct = getAccount(address)
  if acct.getCapability<&{TiblesNFT.CollectionPublic}>(Seussibles.PublicCollectionPath).check() == false {
    return true
  }
  if acct.getCapability<&{FungibleToken.Receiver}>(/public/dapperUtilityCoinReceiver).check() == false {
    return true
  }
  if acct.getCapability<&NFTStorefront.Storefront{NFTStorefront.StorefrontPublic}>(NFTStorefront.StorefrontPublicPath).check() == false {
    return true
  }
  return false
}
