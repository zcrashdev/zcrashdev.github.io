// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "../contracts/TokenEntryJackpot.sol";

interface Vm {
    function expectRevert(bytes4 selector) external;
    function prank(address sender) external;
    function warp(uint256 timestamp) external;
}

contract MockERC20 {
    string public name = "Mock ZCRASH";
    string public symbol = "ZCRASH";
    uint8 public decimals = 18;
    uint256 public feeBps;
    bool public failTransfers;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        if (failTransfers) {
            return false;
        }

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failTransfers) {
            return false;
        }

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        balanceOf[from] -= amount;

        uint256 fee = (amount * feeBps) / 10_000;
        balanceOf[to] += amount - fee;
        return true;
    }

    function setFeeBps(uint256 feeBps_) external {
        feeBps = feeBps_;
    }

    function setFailTransfers(bool failTransfers_) external {
        failTransfers = failTransfers_;
    }
}

contract TokenEntryJackpotTest {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    MockERC20 private token;
    TokenEntryJackpot private jackpot;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private carol = address(0xCA901);
    uint256 private entryAmount = 1_000 ether;
    uint256 private roundDuration = 5 minutes;

    function setUp() public {
        token = new MockERC20();
        jackpot = new TokenEntryJackpot(address(token), entryAmount, roundDuration);

        _fundAndApprove(alice, 10_000 ether);
        _fundAndApprove(bob, 10_000 ether);
        _fundAndApprove(carol, 10_000 ether);
    }

    function testConstructorStartsFirstRound() public view {
        (
            address leader,
            address winner,
            uint256 pot,
            uint256 roundEntryAmount,
            uint256 roundLength,
            uint256 endsAt,
            bool finalized,
            bool claimed
        ) = jackpot.rounds(1);

        _assertEq(jackpot.currentRoundId(), 1);
        _assertEq(roundEntryAmount, entryAmount);
        _assertEq(roundLength, roundDuration);
        _assertEq(endsAt, block.timestamp + roundDuration);
        _assertEq(leader, address(0));
        _assertEq(winner, address(0));
        _assertEq(pot, 0);
        _assertFalse(finalized);
        _assertFalse(claimed);
    }

    function testEnterTransfersTokensAndResetsLeaderAndTimer() public {
        vm.warp(100);
        _enter(alice);

        (address leader,,,,, uint256 endsAt,,) = jackpot.rounds(1);

        _assertEq(leader, alice);
        _assertEq(_pot(1), entryAmount);
        _assertEq(endsAt, block.timestamp + roundDuration);
        _assertEq(token.balanceOf(address(jackpot)), entryAmount);
        _assertEq(token.balanceOf(alice), 9_000 ether);
    }

    function testMultipleEntriesResetTimerAndLatestEntrantWins() public {
        vm.warp(100);
        _enter(alice);

        vm.warp(220);
        _enter(bob);

        (address leader,,,,, uint256 endsAt,,) = jackpot.rounds(1);

        _assertEq(leader, bob);
        _assertEq(_pot(1), 2_000 ether);
        _assertEq(endsAt, 220 + roundDuration);

        vm.warp(endsAt);
        jackpot.finalizeRound();

        (, address winner,,,,,,) = jackpot.rounds(1);
        _assertEq(winner, bob);
    }

    function testFinalizeAndClaimPrize() public {
        _enter(alice);
        _enter(bob);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();

        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        jackpot.claimPrize(1);

        _assertEq(token.balanceOf(bob), bobBalanceBefore + 2_000 ether);
        _assertEq(token.balanceOf(address(jackpot)), 0);
        _assertEq(_pot(1), 0);
    }

    function testWinnerCanClaimOldPrizeAfterNextRoundStarts() public {
        _enter(alice);
        _enter(bob);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();
        jackpot.startNextRound();

        _assertEq(jackpot.currentRoundId(), 2);

        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        jackpot.claimPrize(1);

        _assertEq(token.balanceOf(bob), bobBalanceBefore + 2_000 ether);
    }

    function testAdminRuleChangesOnlyAffectFutureRounds() public {
        _enter(alice);

        uint256 newEntryAmount = 2_500 ether;
        uint256 newDuration = 10 minutes;
        jackpot.setEntryAmount(newEntryAmount);
        jackpot.setRoundDuration(newDuration);

        _enter(bob);

        (,,, uint256 roundOneEntry, uint256 roundOneDuration,,,) = jackpot.rounds(1);
        _assertEq(roundOneEntry, entryAmount);
        _assertEq(roundOneDuration, roundDuration);
        _assertEq(_pot(1), 2_000 ether);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();
        jackpot.startNextRound();

        (,,, uint256 roundTwoEntry, uint256 roundTwoDuration,,,) = jackpot.rounds(2);
        _assertEq(roundTwoEntry, newEntryAmount);
        _assertEq(roundTwoDuration, newDuration);
    }

    function testFeeOnTransferTokenAccountsForActualReceivedAmount() public {
        token.setFeeBps(500);
        _enter(alice);

        _assertEq(_pot(1), 950 ether);
        _assertEq(token.balanceOf(address(jackpot)), 950 ether);
    }

    function testCannotEnterAfterRoundExpiresBeforeFinalize() public {
        vm.warp(_endsAt(1));

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.RoundExpired.selector);
        jackpot.enter();
    }

    function testCannotFinalizeBeforeExpiry() public {
        vm.expectRevert(TokenEntryJackpot.RoundNotExpired.selector);
        jackpot.finalizeRound();
    }

    function testOnlyWinnerCanClaim() public {
        _enter(alice);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();

        vm.prank(bob);
        vm.expectRevert(TokenEntryJackpot.NotWinner.selector);
        jackpot.claimPrize(1);
    }

    function testCannotClaimTwice() public {
        _enter(alice);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();

        vm.prank(alice);
        jackpot.claimPrize(1);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.PrizeAlreadyClaimed.selector);
        jackpot.claimPrize(1);
    }

    function testPauseBlocksEntriesAndNextRoundStarts() public {
        jackpot.setPaused(true);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.Paused.selector);
        jackpot.enter();

        jackpot.setPaused(false);
        _enter(alice);

        vm.warp(_endsAt(1));
        jackpot.finalizeRound();
        jackpot.setPaused(true);

        vm.expectRevert(TokenEntryJackpot.Paused.selector);
        jackpot.startNextRound();
    }

    function testOnlyOwnerCanUpdateConfig() public {
        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NotOwner.selector);
        jackpot.setEntryAmount(2_000 ether);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NotOwner.selector);
        jackpot.setRoundDuration(10 minutes);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NotOwner.selector);
        jackpot.setPaused(true);
    }

    function testZeroReceivedTransferReverts() public {
        token.setFeeBps(10_000);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NoTokensReceived.selector);
        jackpot.enter();
    }

    function testFailedTokenTransferReverts() public {
        token.setFailTransfers(true);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.TransferFailed.selector);
        jackpot.enter();
    }

    function _fundAndApprove(address player, uint256 amount) private {
        token.mint(player, amount);
        vm.prank(player);
        token.approve(address(jackpot), type(uint256).max);
    }

    function _enter(address player) private {
        vm.prank(player);
        jackpot.enter();
    }

    function _pot(uint256 roundId) private view returns (uint256 pot) {
        (,, pot,,,,,) = jackpot.rounds(roundId);
    }

    function _endsAt(uint256 roundId) private view returns (uint256 endsAt) {
        (,,,,, endsAt,,) = jackpot.rounds(roundId);
    }

    function _assertEq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "uint mismatch");
    }

    function _assertEq(address actual, address expected) private pure {
        require(actual == expected, "address mismatch");
    }

    function _assertFalse(bool value) private pure {
        require(!value, "expected false");
    }
}
