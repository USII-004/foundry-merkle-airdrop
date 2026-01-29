// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleAirdrop {
  using SafeERC20 for IERC20;
  // have some list of addresses
  // Allow someone in the list to claim tokens
  error MerkleAirdrop__InvalidProof();
  error MerkleAirdrop__AlreadyClaimed();

  address[] claimers;
  bytes32 private immutable i_merkleRoot;
  IERC20 private immutable i_airdropToken;
  mapping(address claimer => bool claimed) private s_hasClaimed;

  event Claim(address account, uint256 amount);

  constructor(bytes32 merkleRoot, IERC20 airdropToken) {
    i_merkleRoot = merkleRoot;
    i_airdropToken = airdropToken;
  }

  function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {
    // calculate using the account and the amount, the hash -> leaf node
    if(s_hasClaimed[account]) {
      revert MerkleAirdrop__AlreadyClaimed();
    }
    bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    if(!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
      revert MerkleAirdrop__InvalidProof();
    }
    s_hasClaimed[account] = true;
    emit Claim(account, amount);
    i_airdropToken.safeTransfer(account, amount);
  }
}