import Seussibles from 0x321d8fcde05f6e8c
import TiblesNFT from 0x5cdeb067561defcb

// Sending items back to your Tibles account requires first sending them
// to a known Tibles Fowarding Account.
// After the forwarding account receives the items it will send them to
// the owner's Tibles account.
transaction(nftIdsToTransfer: [UInt64]) {
    let forwardingCollection: &{TiblesNFT.CollectionPublic}
    let ownersCollection: &Seussibles.Collection

    prepare(signer: AuthAccount) {
        let tiblesForwardingAcct = getAccount(0x2a4e33da32d2e7ab)
        self.forwardingCollection = tiblesForwardingAcct.getCapability<&{TiblesNFT.CollectionPublic}>(Seussibles.PublicCollectionPath).borrow() 
            ?? panic("Failed to borrow forwarding account collection")
        self.ownersCollection = signer.borrow<&Seussibles.Collection>(from: Seussibles.CollectionStoragePath)
            ?? panic("Failed to borrow collection")
    }

    execute {
        for id in nftIdsToTransfer {
            let tible <- self.ownersCollection.withdrawTible(id: id)
            self.forwardingCollection.depositTible(tible: <- tible)
        }
    }
}