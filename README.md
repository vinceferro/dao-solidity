# Collector Dao

You are writing a contract for Collector DAO, a DAO that aims to collect rare NFTs. This DAO wishes to have a contract that:

- Allows anyone to buy a membership for 1 ETH
- Allows a member to propose an NFT to buy
- Allows members to vote on proposals:
    - With a 25% quorum
- If passed, have the contract purchase the NFT in a reasonably automated fashion.

Voting system doc: see [VOTING.md](VOTING.md)

# Design Exercises

1. Per project specs, there is no vote delegation. This means for someone's vote to count, they must manually participate every time. How would you design your contract to allow for non-transitive vote delegation?

The simplest would be by allowing the voter to delegate their vote by signing a vote call that allows their delegate to vote on their behalf.
For contract development's sake, there would be a new functions that the delegate would call.
Such function would check the signature and register the vote if all checks pass. To avoid abuse of delegate power, the delegatee would also need to use a nonce so that signature is unique. So the checks would be:
- Check that the delegatee address matches the one in the message signed by the voter
- Check that the nonce is valid
- if all checks pass:
  - register the vote
  - update the nonce for the delegatee


2. What are some problems with implementing transitive vote delegation on-chain? (Transitive means: If A delegates to B, and B delegates to C, then C gains voting power from both A and B, while B has no voting power).

The main problem I see is that it's highly gas inefficient as everything happens on chain, so every step is its own transaction.
The order of transaction also matters, so the transactions A->B needs to happen first and mined, then B->C on a different block.

