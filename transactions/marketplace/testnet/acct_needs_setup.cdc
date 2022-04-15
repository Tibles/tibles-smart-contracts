import DapperUtilityCoin from 0x82ec283f88a62e65
import FungibleToken from 0x9a0766d93b6608b7
import NFTStorefront from 0x94b06cfca1d8a476
import NonFungibleToken from 0x631e88ae7f1d7c20
import TiblesNFT from 0xe93c412c964bdf40
import DrSeuss from 0xff68241f0f4fd521

pub fun main(address: Address): Bool {
  let acct = getAccount(address)
  if acct.getCapability<&{TiblesNFT.CollectionPublic}>(DrSeuss.PublicCollectionPath).check() == false {
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
