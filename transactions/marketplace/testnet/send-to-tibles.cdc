import DrSeuss from 0xff68241f0f4fd521
import TiblesNFT from 0xe93c412c964bdf40

// Sending items back to your Tibles account requires first sending them
// to a known Tibles Fowarding Account.
// After the forwarding account receives the items it will send them to
// the owner's Tibles account.
transaction(nftIdsToTransfer: [UInt64]) {
    let forwardingCollection: &{TiblesNFT.CollectionPublic}
    let ownersCollection: &DrSeuss.Collection

    prepare(signer: AuthAccount) {
        let tiblesForwardingAcct = getAccount(0x9617fff4f3b11042)
        self.forwardingCollection = tiblesForwardingAcct.getCapability<&{TiblesNFT.CollectionPublic}>(DrSeuss.PublicCollectionPath).borrow() 
            ?? panic("Failed to borrow forwarding account collection")
        self.ownersCollection = signer.borrow<&DrSeuss.Collection>(from: DrSeuss.CollectionStoragePath)
            ?? panic("Failed to borrow collection")
    }

    execute {
        for id in nftIdsToTransfer {
            let tible <- self.ownersCollection.withdrawTible(id: id)
            self.forwardingCollection.depositTible(tible: <- tible)
        }
    }
}