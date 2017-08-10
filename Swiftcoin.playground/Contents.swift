import Cocoa

protocol BlockPayload {
    var payloadHash: String { get }
}

class Block<P: BlockPayload>: CustomStringConvertible {
    var parent: Block<P>?
    var payload: P
    var nonce: Int
    
    var hash: String {
        let content = (String(describing: parent?.hash)
            + payload.payloadHash
            + String(describing: nonce))
        return content.md5()
    }
    
    init(parent: Block<P>?, payload: P, nonce: Int = 0) {
        self.parent = parent
        self.payload = payload
        self.nonce = nonce
    }
    
    public var description: String {
        return "Block(parent: \(parent?.hash), payload: \(payload), nonce: \(nonce))"
    }
}

extension Data: BlockPayload {
    var payloadHash: String {
        return base64EncodedString()
    }
}

extension String: BlockPayload {
    var payloadHash: String {
        return self
    }
}

struct Blockchain<P: BlockPayload> {
    // difficulty of mining
    //
    var difficulty: Int
    
    // the latest block
    var head: Block<P>
    
    mutating func append(_ block: Block<P>) -> Bool {
        guard block.parent?.hash == head.hash else { return false }
        guard block.isValid(for: self) else { return false }
        head = block
        return true
    }
}

var chain = Blockchain<String>(
    difficulty: 2,
    head: Block(parent: nil, payload: "", nonce: 232)
)

extension Block {
    func isValid(for chain: Blockchain<P>) -> Bool {
        return hash.hasPrefix(String(repeating: "0", count: chain.difficulty))
    }
    
    func mine(for chain: Blockchain<P>) -> Self {
        if isValid(for: chain) {
            return self
        }
        
        for i in 0...Int.max {
            self.nonce = i
            if isValid(for: chain) {
                return self
            }
        }
        fatalError("Could not find proof of work")
    }
}

chain.head.isValid(for: chain)

let transaction = Block<String>(
    parent: chain.head,
    payload: "100 BTC to Thomas",
    nonce: 0
).mine(for: chain)

chain.append(transaction)


// Coins
struct CoinPayload: BlockPayload {
    typealias Input = (name: String, amount: Int)
    typealias Output = (name: String, amount: Int)
    
    let coinbase: Output
    let transactions: [(in: Input, out: Output)]
    
    var payloadHash: String {
        return String(describing: self)
    }

}

struct Ledger {
    let accounts: [String: Int]
    
    init(_ chain: Blockchain<CoinPayload>) {
        var blocks: [Block<CoinPayload>] = [chain.head]
        var currentBlock: Block<CoinPayload> = chain.head
        
        while let next = currentBlock.parent {
            blocks.append(next)
            currentBlock = next
        }
        
        var accounts: [String: Int] = [:]
        for block in blocks.reversed() {
            guard block.isValid(for: chain) else {
                fatalError("Incorrect block: \(block)")
            }
            
            let payload = block.payload
            
            for t in payload.transactions {
                guard t.in.amount == t.out.amount else {
                    fatalError("Unbalanced transaction: \(t)")
                }
                guard let inBalance = accounts[t.in.name], inBalance >= t.in.amount else {
                    fatalError("Overspend: \(t.in.name) spent \(t.in.amount), but has \(accounts[t.in.name] ?? 0)")
                }
                
                accounts[t.in.name] = accounts[t.in.name]! - t.in.amount
                accounts[t.out.name] = (accounts[t.out.name] ?? 0) + t.out.amount
            }
            
            guard payload.coinbase.amount == 100 else {
                fatalError("Invalid coinbase amount")
            }
            accounts[payload.coinbase.name] = (accounts[payload.coinbase.name] ?? 0) + payload.coinbase.amount
        }
        self.accounts = accounts
    }
}

var swiftcoin = Blockchain<CoinPayload>(
    difficulty: 2,
    head: Block(
        parent: nil,
        payload: CoinPayload(
            coinbase: (name: "Thomas", amount: 100),
            transactions: []),
        nonce: 2650))

let block1 = Block<CoinPayload>(
    parent: swiftcoin.head,
    payload: CoinPayload(
        coinbase: (name: "Dave", amount: 100),
        transactions: [
            (in: (name: "Thomas", amount: 50), out: (name: "Mary", amount: 50))
        ]))

block1.mine(for: swiftcoin).nonce
swiftcoin.append(block1)

let block2 = Block<CoinPayload>(
    parent: swiftcoin.head,
    payload: CoinPayload(
        coinbase: (name: "Thomas", amount: 100),
        transactions: [
            (in: (name: "Mary", amount: 20), out: (name: "Liz", amount: 20)),
            (in: (name: "Thomas", amount: 10), out: (name: "Robert", amount: 10)),
            (in: (name: "Thomas", amount: 10), out: (name: "Nancy", amount: 10)),
        ]))

block2.mine(for: swiftcoin).nonce
swiftcoin.append(block2)

//// Uncomment to see how an attempt to steal coins is detected
//block1.payload = CoinPayload(
//    coinbase: (name: "Lars", amount: 100),
//    transactions: [
//        (in: (name: "Thomas", amount: 100), out: (name: "Lars", amount: 100))
//    ])
//block1.nonce = block1.mine(for: swiftcoin).nonce

// Other things to try:
// - spend coins you don't have
// - append an unmined block

Ledger(swiftcoin)
