import { expect } from "chai"
import { ethers, waffle } from "hardhat"
import { CollectorDAO } from "../../src/types/CollectorDAO"
import { BigNumber } from "ethers";
import { Proposal, HashableProposal } from "../types"
import { splitSignature } from "@ethersproject/bytes"

const toHashableProposal = (proposal : Proposal) : HashableProposal => {
  const hashableProposal : HashableProposal = [...proposal]
  hashableProposal[3] = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(proposal[3]))
  return hashableProposal
}

const hashProposal = (dao: CollectorDAO, proposal: Proposal) : Promise<BigNumber> => {
  return dao.hashProposal(...toHashableProposal(proposal));
}

export function shouldHaveAVotingSystem(): void {
  beforeEach(async function() {
    this.dao = <CollectorDAO>await waffle.deployContract(this.signers.deployer, this.daoArtifact)
    await Promise.all(this.signers.members.map(async (member) => {
      await this.dao.connect(member).purchaseMembership({value: ethers.utils.parseEther("1")})
    }))

    const data = this.dao.interface.encodeFunctionData("buyNFT", [this.mkt.address, 1, ethers.utils.parseEther("1")])
    this.proposal = [
      [this.mkt.address],
      [ethers.utils.parseEther("1")],
      [data],
      ""
    ]
    await expect(await this.dao.connect(this.signers.members[0]).propose(...this.proposal)).to.emit(this.dao, "ProposalCreated")
  })

  it("should allow a member to vote only after voting period started", async function () {
    const proposalId = await hashProposal(this.dao, this.proposal);    
    await expect(
      this.dao.connect(this.signers.nonMembers[0]).castVote(proposalId, 1)
    ).to.be.revertedWith("E_VOTER_CANT_VOTE")

    await expect(
      this.dao.connect(this.signers.members[0]).castVote(proposalId, 1)
    ).to.be.revertedWith("E_PROPOSAL_NOT_ACTIVE")

    await ethers.provider.send("hardhat_mine", ["0x1900"]);
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await expect(
      this.dao.connect(this.signers.members[0]).castVote(proposalId, 1)
    ).to.emit(this.dao, "Voted")

    await expect(
      this.dao.connect(this.signers.members[0]).castVote(proposalId, 1)
    ).to.be.revertedWith("E_VOTER_ALREADY_VOTED")
  })

  it("should allow a member to vote by sig", async function () {
    const proposalId = await hashProposal(this.dao, this.proposal);

    const domain = {
      name: "CollectorDAO",
      version: "1",
      chainId: ethers.provider.network.chainId,
      verifyingContract: this.dao.address,
    }
    const vote = {
      proposalId: proposalId,
      vote: 1,
    }
    
    const types = {
      Vote: [
        { name: "proposalId", type: "uint256" },
        { name: "vote", type: "uint8" },
      ],
    }

    const sig1 = splitSignature(await this.signers.nonMembers[0]._signTypedData(domain, types, vote));
    await expect(
      this.dao.connect(this.signers.nonMembers[0]).castVoteBySig(this.signers.nonMembers[0].address, proposalId, 1, sig1.v, sig1.r, sig1.s)
      ).to.be.revertedWith("E_VOTER_CANT_VOTE")

    const sig2 = splitSignature(await this.signers.members[0]._signTypedData(domain, types, vote));
    await expect(
      this.dao.connect(this.signers.members[0]).castVoteBySig(this.signers.members[0].address, proposalId, 1, sig2.v, sig2.r, sig2.s)
    ).to.be.revertedWith("E_PROPOSAL_NOT_ACTIVE")

    await ethers.provider.send("hardhat_mine", ["0x1900"]);
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await expect(
      this.dao.connect(this.signers.members[0]).castVoteBySig(this.signers.members[1].address, proposalId, 0, sig2.v, sig2.r, sig2.s)
    ).to.be.revertedWith("E_UNEXPECTED_VOTER")
    
    await expect(
      this.dao.connect(this.signers.members[0]).castVoteBySig(this.signers.members[0].address, proposalId, 1, sig2.v, sig2.r, sig2.s)
    ).to.emit(this.dao, "Voted")

    await expect(
      this.dao.connect(this.signers.members[0]).castVoteBySig(this.signers.members[0].address, proposalId, 1, sig2.v, sig2.r, sig2.s)
    ).to.be.revertedWith("E_VOTER_ALREADY_VOTED")
  })

  it("should allow bulk voting", async function () {
    const proposalId = await hashProposal(this.dao, this.proposal);

    const domain = {
      name: "CollectorDAO",
      version: "1",
      chainId: ethers.provider.network.chainId,
      verifyingContract: this.dao.address,
    }
    const vote = {
      proposalId: proposalId,
      vote: 1,
    }
    
    const types = {
      Vote: [
        { name: "proposalId", type: "uint256" },
        { name: "vote", type: "uint8" },
      ],
    }

    const allSigners = [...this.signers.members, ...this.signers.nonMembers];

    const sigs = await Promise.all(allSigners.map(async (signer) => {
      return splitSignature(await signer._signTypedData(domain, types, vote))
    }))

    await ethers.provider.send("hardhat_mine", ["0x1900"])
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await expect(await this.dao.connect(this.signers.deployer).callStatic.castVoteBySigBulk(
      allSigners.map((signer) => signer.address),
      new Array(10).fill(proposalId),
      new Array(10).fill(1),
      sigs.map((sig) => sig.v),
      sigs.map((sig) => sig.r),
      sigs.map((sig) => sig.s),
    )).to.eq(5)

  })

  it("should execute based on quorum", async function () {
    const proposalId = await hashProposal(this.dao, this.proposal);
    const hashableProposal = toHashableProposal(this.proposal)
    await expect(
      this.dao.execute(...hashableProposal)
    ).to.be.revertedWith("E_PROPOSAL_NOT_EXECUTABLE")

    await ethers.provider.send("hardhat_mine", ["0x1900"])
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    // Situation with for: 2, agains: 1, abstain: 2
    const votes = {
      [this.signers.members[0].address]: 1,
      [this.signers.members[1].address]: 2,
      [this.signers.members[2].address]: 1,
      [this.signers.members[3].address]: 0,
      [this.signers.members[4].address]: 0,
    }

    await Promise.all(this.signers.members.map(async (signer) => {
      await this.dao.connect(signer).castVote(proposalId, votes[signer.address])
    }))

    await expect(
      this.dao.execute(...hashableProposal)
    ).to.be.revertedWith("E_PROPOSAL_NOT_EXECUTABLE")

    await ethers.provider.send("hardhat_mine", ["0xAF00"])
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await expect(() => this.dao.execute(...hashableProposal)).to
      .changeEtherBalances([this.dao, this.mkt], [ethers.utils.parseEther("-1"), ethers.utils.parseEther("1")])
    
    expect(await this.dao.state(proposalId)).to.eq(4)
  })

  it("should defeat on quorum", async function () {
    const proposalId = await hashProposal(this.dao, this.proposal);
    const hashableProposal = toHashableProposal(this.proposal)
    await expect(
      this.dao.execute(...hashableProposal)
    ).to.be.revertedWith("E_PROPOSAL_NOT_EXECUTABLE")

    await ethers.provider.send("hardhat_mine", ["0x1900"])
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await Promise.all(this.signers.members.map(async (signer) => {
      await this.dao.connect(signer).castVote(proposalId, 0)
    }))

    await expect(
      this.dao.execute(...hashableProposal)
    ).to.be.revertedWith("E_PROPOSAL_NOT_EXECUTABLE")

    await ethers.provider.send("hardhat_mine", ["0xAF00"])
    await ethers.provider.send('hardhat_setNextBlockBaseFeePerGas', ['0x0'])

    await expect(
      this.dao.execute(...hashableProposal)
    ).to.be.revertedWith("E_PROPOSAL_NOT_EXECUTABLE")
    expect(await this.dao.state(proposalId)).to.eq(2)
  })
}
