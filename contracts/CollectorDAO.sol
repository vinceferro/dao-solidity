// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Utils.sol";
import "./Checkpoints.sol";

/**
 * @title CollectoDAO
 * @author TheV
 */
contract CollectorDAO {

    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    using Checkpoints for Checkpoints.History;
    uint256 public constant MEMBERSHIP_FEE = 1 ether;
    uint256 public constant QUORUM = 25;
    uint256 public constant BLOCKS_PER_DAY = 6400;
    uint256 public constant VOTING_DELAY = 1 * BLOCKS_PER_DAY;
    uint256 public constant VOTING_PERIOD = 7 * BLOCKS_PER_DAY;
    
    uint256 public lastBlock = 0;
    uint256 public membersCount = 0;
    Checkpoints.History private _membershipCheckpoints;
    
    bytes32 public constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );
    bytes32 public constant VOTE_TYPEHASH = keccak256("Vote(uint256 proposalId,uint8 vote)");
    bytes32 public DOMAIN_SEPARATOR;

    mapping (address => uint256) public memberSince;

    enum VoteType {
        Abstain,
        For,
        Against
    }

    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Executed
    }

    struct Proposal {
        uint256 voteBegin;
        uint256 voteEnd;
        uint256 againstVotes;
        uint256 forVotes;
        uint256 abstainVotes;
        bool executed;
        mapping(address => bool) voters;
    }
    mapping (uint256 => Proposal) private _proposals;


    event MembershipPurchased(address member, uint256 blockNumber);
    event ProposalCreated(uint256 proposalId, address creator);
    event Voted(uint256 proposalId, address voter, VoteType vote);

    /**
     * @dev Initialize EIP712 domain separator
     */
    constructor () {
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "CollectorDAO",
            version: "1",
            chainId: block.chainid,
            verifyingContract: address(this)
        }));
    }

    /**
     * @dev Calculates the EIP712 domain separator hash
     */
    function hash(EIP712Domain memory eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    /**
     * @notice Purchase a membership for 1 ETH
     * @dev handles checkpoints using Checkpoints library
     */
    function purchaseMembership() external payable {
        require(msg.value == MEMBERSHIP_FEE, "E_INVALID_MEMBERSHIP_FEE");
        require(memberSince[msg.sender] == 0, "E_MEMBER_ALREADY_EXISTS");
        require(lastBlock <= block.number, "E_INVALID_BLOCK_NUMBER");
        if (lastBlock != block.number) {
            _membershipCheckpoints.push(membersCount);
            lastBlock = block.number;
        }
        membersCount++;
        memberSince[msg.sender] = block.number;
        emit MembershipPurchased(msg.sender, block.number);
    }


    /**
     * @notice allow the DAO to buy the nft
     * @param nftContract address of the nft contract
     * @param nftId uint256 id of the nft
     * @param price uint256 price of the nft
     */
    function buyNFT(address nftContract, uint256 nftId, uint256 price) public payable {
        require(msg.sender == address(this), "E_ONLY_GOVERNANCE");
        NftMarketplace mktplace = NftMarketplace(nftContract);
        uint256 nftPrice = mktplace.getPrice(nftContract, nftId);
        require(nftPrice <= price, "E_INVALID_PRICE");
        bool success = mktplace.buy{value: nftPrice}(nftContract, nftId);
        require(success, "E_BUY_FAILED");
    }

    /**
     * @notice Allow members to create a proposal
     * @param targets array representing the call to make
     * @param values array representing the value of ETH sent to the call
     * @param calldatas array representing the data to be sent to the call
     * @param description description of the proposal
     */
    function propose(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description
    ) public returns (uint256) {
        require(memberSince[msg.sender] > 0, "E_MEMBER_NOT_FOUND");

        uint256 proposalId = hashProposal(targets, values, calldatas, keccak256(bytes(description)));

        require(targets.length == values.length, "E_INVALID_PROPOSAL");
        require(targets.length == calldatas.length, "E_INVALID_PROPOSAL");
        require(targets.length > 0, "E_INVALID_PROPOSAL");

        Proposal storage proposal = _proposals[proposalId];
        require(proposal.voteBegin == 0, "E_PROPOSAL_EXISTS");

        uint256 voteBegin = block.number + VOTING_DELAY;
        proposal.voteBegin = voteBegin;
        proposal.voteEnd =  voteBegin + VOTING_PERIOD;

        emit ProposalCreated(
            proposalId,
            msg.sender
        );

        return proposalId;
    }

    /**
     * @notice publicly available execute call.
     * @dev delegates the actual excecution to _execute
     */
    function execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public payable returns (uint256) {
        uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);

        ProposalState status = state(proposalId);
        require(
            status == ProposalState.Succeeded,
            "E_PROPOSAL_NOT_EXECUTABLE"
        );
        _proposals[proposalId].executed = true;

        _execute(targets, values, calldatas);

        return proposalId;
    }

    /**
     * @dev Internal execution mechanism.
     * @param targets array representing the call to make
     * @param values array representing the value of ETH sent to the call
     * @param calldatas array representing the data to be sent to the call
     */
    function _execute(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas
    ) internal {
        string memory errorMessage = "E_EXECUTION_FAILED";
        for (uint256 i = 0; i < targets.length; ++i) {
            (bool success, bytes memory returndata) = targets[i].call{value: values[i]}(calldatas[i]);
            verifyCallResult(success, returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            if (returndata.length > 0) {
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }


    /**
     * @notice calculatets the state of a proposal
     * @dev get the proposal from storage, returns executed or canceled first
     * then checks if the proposal is active
     * if not active it checks the actual voting results
     */
    function state(uint256 proposalId) public view returns (ProposalState) {
        Proposal storage proposal = _proposals[proposalId];
        require(proposal.voteBegin > 0, "E_PROPOSAL_NOT_FOUND");
        if (proposal.executed) {
            return ProposalState.Executed;
        }

        if (proposal.voteBegin > block.number) {
            return ProposalState.Pending;
        }

        if (proposal.voteEnd >= block.number) {
            return ProposalState.Active;
        }

        if (_quorumReached(proposalId) && _voteSucceeded(proposalId)) {
            return ProposalState.Succeeded;
        } else {
            return ProposalState.Defeated;
        }
    }

    /**
     * @notice check if quorum was reached
     * @param proposalId uint256 id of the proposal
     * @return bool true if quorum was reached, false otherwise
     */
    function _quorumReached(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        return quorum(proposal.voteBegin) <= proposal.forVotes + proposal.abstainVotes;
    }

    /**
     * @notice check if the vote succeeded
     * @dev the vote succeded if the for votes is greater than the against votes
     * @param proposalId uint256 id of the proposal
     * @return bool true if the vote succeeded, false otherwise
     */
    function _voteSucceeded(uint256 proposalId) internal view returns (bool) {
        Proposal storage proposal = _proposals[proposalId];
        return proposal.forVotes > proposal.againstVotes;
    }

    /**
     * @notice calculates the quorum at a given block number
     * @param blockNumber uint256 block number
     */
    function quorum(uint256 blockNumber) public view returns (uint256) {
        return _membershipCheckpoints.getAtBlock(blockNumber) * QUORUM / 100;
    }

    /**
     * @notice verify vote signature
     * @param expectedVoter address of the expected voter
     * @param proposalId uint256 id of the proposal
     * @param vote uint8 represent the vote (0 abstain, 1 for, 2 against)
     * @param v, r, s signature of the voter
     */
    function _verifySig(
        address expectedVoter,
        uint256 proposalId,
        VoteType vote,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view {
        bytes32 structHash = keccak256(abi.encode(VOTE_TYPEHASH, proposalId, vote));
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            structHash
        ));
        address voter = ecrecover(digest, v, r, s);
        require(voter != address(0), "E_INVALID_SIGNATURE");
        require(voter == expectedVoter, "E_UNEXPECTED_VOTER");
    }

    /**
     * @notice allow voting
     * @param proposalId uint256 id of the proposal
     * @param vote uint8 represent the vote (0 abstain, 1 for, 2 against)
     */
    function castVote(
        uint256 proposalId,
        VoteType vote
    ) external {
        _castVote(proposalId, msg.sender, vote);
    }

    /**
     * @notice allow voting by signature
     * @param voter address of the voter
     * @param proposalId uint256 id of the proposal
     * @param vote uint8 represent the vote (0 abstain, 1 for, 2 against)
     * @param v, r, s signature of the voter
     */
    function castVoteBySig(
        address voter,
        uint256 proposalId,
        VoteType vote,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        _verifySig(voter, proposalId, vote, v, r, s);
        _castVote(proposalId, voter, vote);
    }

    /**
     * @notice cast vots in bulk
     */
    function castVoteBySigBulk(
        address[] memory expectedVoters,
        uint256[] memory proposalIds,
        VoteType[] memory votes,
        uint8[] memory v,
        bytes32[] memory r,
        bytes32[] memory s
    ) external returns (uint256) {
        uint256 registeredVotes = 0;
        require(expectedVoters.length == proposalIds.length &&
            expectedVoters.length == votes.length &&
            expectedVoters.length == v.length &&
            expectedVoters.length == r.length &&
            expectedVoters.length == s.length,
            "E_INVALID_ARGUMENT");
        for (uint256 i = 0; i < expectedVoters.length; ++i) {
            (bool callSuccess, ) = address(this).call(
                abi.encodeWithSignature(
                    "castVoteBySig(address,uint256,uint8,uint8,bytes32,bytes32)",
                    expectedVoters[i],
                    proposalIds[i],
                    votes[i],
                    v[i],
                    r[i],
                    s[i]
                )
            );
            if (callSuccess) {
                registeredVotes++;
            }
        }
        return registeredVotes;
    }

   /**
     * @notice allow voting for a proposal
     * @dev internal function, use castVoteBySig instead
     * @param proposalId uint256 id of the proposal
     * @param voter address of the voter
     * @param vote VoteType represent the vote (0 abstain, 1 for, 2 against)
     */
    function _castVote(
        uint256 proposalId,
        address voter,
        VoteType vote
    ) internal {
        Proposal storage proposal = _proposals[proposalId];
        require(memberSince[voter] > 0 && proposal.voteBegin >= memberSince[voter], "E_VOTER_CANT_VOTE");
        require(state(proposalId) == ProposalState.Active, "E_PROPOSAL_NOT_ACTIVE");
        require(proposal.voters[voter] == false, "E_VOTER_ALREADY_VOTED");
        // Leveraging the fact that the enum is uint8 and Against is the last value
        require(vote <= VoteType.Against, "E_INVALID_VOTE"); 

        if (vote == VoteType.Abstain) {
            proposal.abstainVotes++;
        } else if (vote == VoteType.For) {
            proposal.forVotes++;
        } else {
            proposal.againstVotes++;
        }

        proposal.voters[voter] = true;
        emit Voted(
            proposalId,
            voter,
            vote
        );
    }


    /**
     * @notice Create proposal hash
     * @param targets address[] array of targets
     * @param values uint256[] array of values to send to the targets
     * @param calldatas bytes[] array of calldatas
     * @param descriptionHash bytes32 hash of the description of the proposal
     */
    function hashProposal(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) public pure virtual returns (uint256) {
        return uint256(keccak256(abi.encode(targets, values, calldatas, descriptionHash)));
    }
}