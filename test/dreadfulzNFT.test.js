const { expect } = require("chai")
const hre = require("hardhat")
const { ethers } = require("hardhat")
const { BigNumber } = require("ethers")
const {
	expectRevert
} = require('@openzeppelin/test-helpers');
const { MerkleTree } = require('merkletreejs');
const keccak256 = require('keccak256');
const web3 = require('web3');

let dreadfulzNFT;
let nft;
let owner;
let account1;
let account2;
let reserveAddress;
let merkleTree;
let leaves;

function hashToken(account) {
	return Buffer.from(ethers.utils.solidityKeccak256(['address'], [account]).slice(2), 'hex')
}

function freeClaimHexProof(count, addressToCheck) {
	const addressHash = web3.utils.soliditySha3(count, addressToCheck);
	const hexProof = merkleTree.getHexProof(addressHash);
  
	return hexProof;
}

describe("DreadfulzNFT", function () {
	before(async function () {
		let wallets = await ethers.getSigners();
		owner = wallets[0]
		account1 = wallets[1]
		account2 = wallets[3]
		reserveAddress = wallets[2]

		// console.log("root", merkleTreeFreeClaim.getRoot().toString("hex"));
		// console.log('combine hash' ,web3.utils.soliditySha3(4,'0x351876Fa509E2b7E0ffdE254e048e39140028Af9').toString('hex'));
		
		dreadfulzNFT = await ethers.getContractFactory("DreadfulzNFT")
		nft = await dreadfulzNFT.deploy();

		leaves = wallets.map((account, index) => web3.utils.soliditySha3(index, account.address));
		merkleTree = new MerkleTree(leaves, keccak256, {
			sortPairs: true,
		});
	})

	describe("presale feature", async () => {
		before(async () => {
			await nft.setSaleActive();
			await nft.setMerkleRoot(merkleTree.getHexRoot());
		});
		it('should success on presale mint', async () => {
			let proofs = freeClaimHexProof(1, account1.address);

			await nft.connect(account1).presale(1, account1.address, proofs, { value: ethers.utils.parseEther('0.07') });
			expect(await nft.ownerOf(0)).to.be.equal(account1.address);
		});

		it('should fail on presale mint with wrong amount of quantity', async () => {
			let proofs = freeClaimHexProof(1, account2.address);

			expectRevert(
				nft.connect(account2).presale(1, proofs, { value: ethers.utils.parseEther('0.07') }),
				"Invalid Proof"
			);
			expect(await nft.ownerOf(0)).to.be.equal(account1.address);
		});

	})
	describe("public sale feature", async () => {
		before(async () => {
			await nft.setSaleActive();
		});
		it('should success on public mint', async () => {
			await nft.connect(account1).mint(1, { value: ethers.utils.parseEther('0.07') });
			expect(await nft.ownerOf(0)).to.be.equal(account1.address);
		});
	})
})