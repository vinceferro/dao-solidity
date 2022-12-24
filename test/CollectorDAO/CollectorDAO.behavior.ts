import { expect } from "chai"
import { ethers, waffle } from "hardhat"

import type { CollectorDAO } from "../../src/types/CollectorDAO"
import type { Proposal } from "../types"


export function shouldBehaveLikeCollectorDAO(): void {
  beforeEach(async function () {
    this.dao = <CollectorDAO>await waffle.deployContract(this.signers.deployer, this.daoArtifact)
    await Promise.all(this.signers.members.map(async (member) => {
      await this.dao.connect(member).purchaseMembership({value: ethers.utils.parseEther("1")})
    }))
  })

  it("should allow buy membership for 1 ETH", async function () {
    await expect(this.dao.connect(this.signers.nonMembers[0]).purchaseMembership({value: ethers.utils.parseEther("1.1")})).to.be.revertedWith("E_INVALID_MEMBERSHIP_FEE")
    await expect(this.dao.connect(this.signers.nonMembers[0]).purchaseMembership({value: ethers.utils.parseEther("1")})).to.be.ok
    await expect(this.dao.connect(this.signers.nonMembers[0]).purchaseMembership({value: ethers.utils.parseEther("1")})).to.be.revertedWith("E_MEMBER_ALREADY_EXISTS")
  })

  it("should allow members to propose buying an NFT", async function () {
    const data = this.dao.interface.encodeFunctionData("buyNFT", [this.mkt.address, 1, ethers.utils.parseEther("1")])
    const proposal : Proposal = [
      [this.mkt.address],
      [ethers.utils.parseEther("1")],
      [data],
      ""
    ]
    await expect(this.dao.connect(this.signers.members[0]).propose(...proposal)).to.be.ok
    await expect(this.dao.connect(this.signers.members[0]).propose(...proposal)).to.be.revertedWith("E_PROPOSAL_EXISTS")
  })
}

