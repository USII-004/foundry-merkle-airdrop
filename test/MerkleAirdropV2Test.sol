// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MerkleAirdropV2} from "../src/MerkleAirdropV2.sol";
import {BagelToken} from "../src/BagelToken.sol";

/**
 * @title  MerkleAirdropV2Test
 * @notice Comprehensive test suite covering all V2 features.
 *
 * Run with:
 *   forge test --match-contract MerkleAirdropV2Test -vvvv
 */
contract MerkleAirdropV2Test is Test {
    // ── Fixtures ─────────────────────────────────────────────────────────────
    BagelToken      public token;
    MerkleAirdropV2 public airdrop;

    bytes32 public constant ROOT =
        0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;

    uint256 public constant AMOUNT_TO_CLAIM = 25e18;
    uint256 public constant AMOUNT_TO_SEND  = AMOUNT_TO_CLAIM * 4;

    // Proof for address[0] (0x6CA6…)
    bytes32 PROOF_ONE = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 PROOF_TWO = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF;

    address public gasPayer;
    address public user;
    uint256 public userPrivKey;

    // ── Setup ─────────────────────────────────────────────────────────────────
    function setUp() public {
        PROOF.push(PROOF_ONE);
        PROOF.push(PROOF_TWO);

        token   = new BagelToken();
        airdrop = new MerkleAirdropV2(ROOT, token, 0); // no deadline initially

        token.mint(address(this), AMOUNT_TO_SEND);
        token.transfer(address(airdrop), AMOUNT_TO_SEND);

        (user, userPrivKey) = makeAddrAndKey("user");
        gasPayer = makeAddr("gasPayer");
    }

    // ── Helper ────────────────────────────────────────────────────────────────
    function _sign(address _account, uint256 _amount, uint256 _privKey)
        internal view
        returns (uint8 v, bytes32 r, bytes32 s)
    {
        bytes32 digest = airdrop.getMessageHash(_account, _amount);
        (v, r, s) = vm.sign(_privKey, digest);
    }

    // ══════════════════════════════ CORE CLAIM ════════════════════════════════

    function testSelfClaimSucceeds() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.prank(user);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
        assertTrue(airdrop.hasClaimed(user));
        assertEq(airdrop.claimedAmount(user), AMOUNT_TO_CLAIM);
        assertEq(airdrop.totalClaimed(), AMOUNT_TO_CLAIM);
    }

    function testRelayerClaimSucceeds() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.prank(gasPayer); // relayer pays gas
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
    }

    function testCannotClaimTwice() public {
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.startPrank(gasPayer);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__AlreadyClaimed.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
        vm.stopPrank();
    }

    function testInvalidProofReverts() public {
        bytes32[] memory badProof = new bytes32[](2);
        badProof[0] = keccak256("bad");
        badProof[1] = keccak256("proof");

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__InvalidProof.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, badProof, v, r, s);
    }

    function testInvalidSignatureReverts() public {
        (, uint256 badPrivKey) = makeAddrAndKey("attacker");
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, badPrivKey);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__InvalidSignature.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    // ══════════════════════════════ CLAIM WINDOW ═════════════════════════════

    function testClaimFailsAfterDeadline() public {
        uint256 deadline = block.timestamp + 7 days;
        airdrop.setClaimDeadline(deadline);

        vm.warp(deadline + 1);

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__AirdropExpired.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    function testClaimSucceedsBeforeDeadline() public {
        airdrop.setClaimDeadline(block.timestamp + 7 days);

        vm.warp(block.timestamp + 3 days);

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
    }

    // ══════════════════════════════ FOOTPRINT GATE ════════════════════════════

    function testFootprintGate_BlocksLowBalance() public {
        // Require at least 0.1 ETH
        airdrop.setFootprintRequirement(0.1 ether, 0);

        // user has 0 ETH by default
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__InsufficientOnchainFootprint.selector);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    function testFootprintGate_PassesWithSufficientBalance() public {
        airdrop.setFootprintRequirement(0.1 ether, 0);

        vm.deal(user, 0.5 ether); // fund the user

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
    }

    function testFootprintGate_DisabledByDefault() public {
        // No requirement set → anyone with a valid proof can claim
        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertTrue(airdrop.hasClaimed(user));
    }

    // ══════════════════════════════ PAUSE ════════════════════════════════════

    function testPausedClaimReverts() public {
        airdrop.pause();

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        vm.expectRevert(); // Pausable: paused
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
    }

    function testUnpauseRestoresClaims() public {
        airdrop.pause();
        airdrop.unpause();

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);
        airdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
    }

    function testOnlyOwnerCanPause() public {
        vm.prank(gasPayer);
        vm.expectRevert();
        airdrop.pause();
    }

    // ══════════════════════════════ CLAWBACK ═════════════════════════════════

    function testRecoverTokensAfterExpiry() public {
        uint256 deadline = block.timestamp + 30 days;
        airdrop.setClaimDeadline(deadline);

        vm.warp(deadline + 1);

        address treasury = makeAddr("treasury");
        uint256 contractBal = token.balanceOf(address(airdrop));

        airdrop.recoverTokens(treasury);

        assertEq(token.balanceOf(treasury), contractBal);
        assertEq(token.balanceOf(address(airdrop)), 0);
    }

    function testRecoverTokensRevertsBeforeExpiry() public {
        airdrop.setClaimDeadline(block.timestamp + 30 days);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__AirdropNotExpired.selector);
        airdrop.recoverTokens(address(this));
    }

    function testRecoverTokensRevertsWithNoDeadline() public {
        // deadline == 0
        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__ClaimWindowNotSet.selector);
        airdrop.recoverTokens(address(this));
    }

    // ══════════════════════════════ BATCH CLAIM ═══════════════════════════════

    /// @dev Single-item batch (proves the path works end-to-end)
    function testBatchClaimSingleEntry() public {
        address[] memory accounts  = new address[](1);
        uint256[] memory amounts   = new uint256[](1);
        bytes32[][] memory proofs  = new bytes32[][](1);
        uint8[]   memory vs        = new uint8[](1);
        bytes32[] memory rs        = new bytes32[](1);
        bytes32[] memory ss        = new bytes32[](1);

        accounts[0]  = user;
        amounts[0]   = AMOUNT_TO_CLAIM;
        proofs[0]    = PROOF;
        (vs[0], rs[0], ss[0]) = _sign(user, AMOUNT_TO_CLAIM, userPrivKey);

        airdrop.batchClaim(accounts, amounts, proofs, vs, rs, ss);

        assertEq(token.balanceOf(user), AMOUNT_TO_CLAIM);
    }

    function testBatchClaimLengthMismatchReverts() public {
        address[] memory accounts = new address[](2);
        uint256[] memory amounts  = new uint256[](1); // wrong length
        bytes32[][] memory proofs = new bytes32[][](2);
        uint8[]   memory vs       = new uint8[](2);
        bytes32[] memory rs       = new bytes32[](2);
        bytes32[] memory ss       = new bytes32[](2);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__ArrayLengthMismatch.selector);
        airdrop.batchClaim(accounts, amounts, proofs, vs, rs, ss);
    }

    // ══════════════════════════════ VIEW HELPERS ══════════════════════════════

    function testViewHelpers() public {
        assertEq(airdrop.getMerkleRoot(), ROOT);
        assertEq(address(airdrop.getAirdropToken()), address(token));
        assertEq(airdrop.remainingBalance(), AMOUNT_TO_SEND);
        assertFalse(airdrop.isExpired());

        airdrop.setClaimDeadline(block.timestamp + 1);
        vm.warp(block.timestamp + 2);
        assertTrue(airdrop.isExpired());
    }

    // ══════════════════════════════ FUZZ ══════════════════════════════════════

    /// @dev Fuzzing ensures no phantom amounts are accepted by the Merkle proof.
    function testFuzz_WrongAmountRejected(uint256 wrongAmount) public {
        vm.assume(wrongAmount != AMOUNT_TO_CLAIM);
        vm.assume(wrongAmount != 0); // avoid trivial zero-amount case

        (uint8 v, bytes32 r, bytes32 s) = _sign(user, wrongAmount, userPrivKey);

        vm.expectRevert(MerkleAirdropV2.MerkleAirdrop__InvalidProof.selector);
        airdrop.claim(user, wrongAmount, PROOF, v, r, s);
    }
}
