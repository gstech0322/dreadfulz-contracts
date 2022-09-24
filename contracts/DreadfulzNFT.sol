//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

contract DreadfulzNFT is Ownable, ReentrancyGuard, ERC721A, PaymentSplitter {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.UintToAddressMap;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Enumerable mapping from token ids to their owners
    EnumerableMap.UintToAddressMap private _tokenOwners;

	bytes32 public merkleRoot = 0xca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb;

	mapping(address => bool) public whitelistClaimed;

	bool public isSaleActive = false;
	bool public is2ndSaleActive = false;
	bool public isFinalSaleActive = false;

	uint public RESERVED_AMOUNT = 50;
	uint public FIRST_SALE_AMOUNT = 222;
	uint public SECOND_SALE_AMOUNT = 2000;
	uint public FINAL_SALE_AMOUNT = 2000;

	uint public PRESALE_PRICE = 0.03 ether;
	uint public FIRST_SALE_PRICE = 0.04 ether;
	uint public SECOND_SALE_PRICE = 0.05 ether;
	uint public FINAL_SALE_PRICE = 0.06 ether;

	address payable private DEV_WALLET = payable(0xD387098B3CA4C6D592Be0cE0B69E83BE86011c50);
	address payable private MARKETING_WALLET = payable(0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266);

    address[] public payees = [DEV_WALLET, MARKETING_WALLET];
    uint[] public shares = [30, 70];
	
	event DetectAddress(bytes32 root, bytes32[] proof, bytes32 leaf);

	constructor() ERC721A("Dreadfulz NFT", "DRF", 5) PaymentSplitter(payees, shares) payable {}

	/**
	 * @dev general sale function
	 * @param quantity amount to mint
	 */
	function mint(uint256 quantity) external nonReentrant payable {
		// _safeMint's second argument now takes in a quantity, not a tokenId.
		require(isSaleActive || is2ndSaleActive || isFinalSaleActive, "Sale not started yet");

		uint currentPrice = FIRST_SALE_PRICE;
		if(isSaleActive) {
			require(totalSupply() + quantity < RESERVED_AMOUNT + FIRST_SALE_AMOUNT, "Exceed 1st Sale amount");
		}
		if(is2ndSaleActive) {
			currentPrice = SECOND_SALE_PRICE;
			require(totalSupply() + quantity < RESERVED_AMOUNT + FIRST_SALE_AMOUNT + SECOND_SALE_AMOUNT, "Exceed 2nd Sale amount");
		}
		if(isFinalSaleActive) {
			currentPrice = FINAL_SALE_PRICE;
			require(totalSupply() + quantity < RESERVED_AMOUNT + FIRST_SALE_AMOUNT + SECOND_SALE_AMOUNT + FINAL_SALE_AMOUNT, "Exceed 2nd Sale amount");
		}
		require(msg.value >= currentPrice * quantity, "Not enough payment");
        for(uint i = totalSupply(); i < totalSupply() + quantity; i += 1) {
            _holderTokens[msg.sender].add(i);

            _tokenOwners.set(i, msg.sender);
        }
		_safeMint(msg.sender, quantity);
	}

	function presale(uint256 quantity, address account, bytes32[] calldata _merkleProof) external nonReentrant payable {
		require(msg.sender == account, "Cannot mint for other address");
		require(isSaleActive || is2ndSaleActive || isFinalSaleActive, "Sale not started yet");

		require(msg.value >= PRESALE_PRICE * quantity, "Not enough payment");
		require(!whitelistClaimed[msg.sender], "Address has already claimed");

		bytes32 leaf = keccak256(abi.encodePacked(quantity, account));
		require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "Invalid Proof");

		whitelistClaimed[msg.sender] = true;
        for(uint i = totalSupply(); i < totalSupply() + quantity; i += 1) {
            _holderTokens[msg.sender].add(i);

            _tokenOwners.set(i, msg.sender);
        }
		_safeMint(msg.sender, quantity);
	}


    /**
     * @dev balance of owner address
     */
    function balanceOfOwner(address owner) public view returns (uint256) {
        require(owner != address(0), "ERC721: balance query for the zero address");

        return _holderTokens[owner].length();
    }

	/// -------- Admin functions ---------- ///

	/**
	 * @dev mint NFTs to team
	 * @param to_ address to mint
	 * @param quantity_ amount of nft to be minted
	 */
	function mintToTeam(address to_, uint256 quantity_) external onlyOwner {
		require(totalSupply() + quantity_ < RESERVED_AMOUNT, "Exceeds reserved amount for team");
		_safeMint(to_, quantity_);
	}

	/**
	 * @dev make first sale stage active
	 */
	function setSaleActive() external onlyOwner {
		isSaleActive = true;
	}

	/**
	 * @dev make 2nd sale stage active
	 */
	function set2ndSaleActive() external onlyOwner {
		isSaleActive = false;
		is2ndSaleActive = true;
	}

	/**
	 * @dev make final sale stage active
	 */
	function setFinalSaleActive() external onlyOwner {
		isSaleActive = false;
		is2ndSaleActive = false;
		isFinalSaleActive = true;
	}

	/**
	 * @dev update merkleRoot
	 * @param _merkleRoot new value
	 */
	function setMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
		merkleRoot = _merkleRoot;
	}
}