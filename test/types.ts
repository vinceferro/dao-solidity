import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address"
import type { Fixture } from "ethereum-waffle"
import type { Artifact } from "hardhat/types"
import type { CollectorDAO } from "../src/types/CollectorDAO"
import type { NftMarketplace } from "../src/types/NftMarketplace"
import type { FakeContract } from "@defi-wonderland/smock"
import type { BigNumberish, BytesLike } from "ethers"

declare module "mocha" {
  export interface Context {
    daoArtifact: Artifact;
    dao: CollectorDAO;
    loadFixture: <T>(fixture: Fixture<T>) => Promise<T>;
    mkt: FakeContract<NftMarketplace>;
    proposal: Proposal;
    signers: Signers;
  }
}

export interface Signers {
  deployer: SignerWithAddress;
  members: SignerWithAddress[];
  nonMembers: SignerWithAddress[];
}

export declare type Proposal = [string[], BigNumberish[], BytesLike[], string]
export declare type HashableProposal = [string[], BigNumberish[], BytesLike[], BytesLike]