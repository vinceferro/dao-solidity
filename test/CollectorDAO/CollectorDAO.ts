import { artifacts, ethers } from "hardhat"
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"
import { smock } from "@defi-wonderland/smock"

import { Signers } from "../types"
import { shouldBehaveLikeCollectorDAO } from "./CollectorDAO.behavior"
import { NftMarketplace } from "../../src/types/NftMarketplace"
import { shouldHaveAVotingSystem } from "./Voting.behavior"

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers
    const signers: SignerWithAddress[] = await ethers.getSigners()
    this.signers.deployer = signers.splice(0, 1)[0]

    this.daoArtifact = await artifacts.readArtifact("CollectorDAO")
    this.mkt = await smock.fake<NftMarketplace>('NftMarketplace')


    this.signers.members = signers.splice(0, 5)
    this.signers.nonMembers = signers.splice(0, 5)
  });

  describe("CollectorDAO", function () {
    shouldBehaveLikeCollectorDAO()
  });

  describe("Voting", function () {
    shouldHaveAVotingSystem()
  })
})
