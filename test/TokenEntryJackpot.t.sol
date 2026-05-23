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
        if (failTransfers) return false;
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        if (failTransfers) return false;

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
    uint256 private jackpotDuration = 5 minutes;

    function setUp() public {
        token = new MockERC20();
        jackpot = new TokenEntryJackpot(address(token), entryAmount, jackpotDuration);

        _fundAndApprove(alice, 10_000 ether);
        _fundAndApprove(bob, 10_000 ether);
        _fundAndApprove(carol, 10_000 ether);
    }

    function testConstructorInitializesJackpot() public view {
        _assertEq(address(jackpot.token()), address(token));
        _assertEq(jackpot.owner(), address(this));
        _assertEq(jackpot.entryAmount(), entryAmount);
        _assertEq(jackpot.jackpotDuration(), jackpotDuration);
        _assertEq(jackpot.endsAt(), block.timestamp + jackpotDuration);
        _assertEq(jackpot.pot(), 0);
        _assertEq(jackpot.leader(), address(0));
        _assertEq(jackpot.lastWinner(), address(0));
    }

    function testEnterTransfersTokensAndResetsLeaderAndTimer() public {
        vm.warp(100);
        _enter(alice);

        _assertEq(jackpot.leader(), alice);
        _assertEq(jackpot.pot(), entryAmount);
        _assertEq(jackpot.endsAt(), block.timestamp + jackpotDuration);
        _assertEq(token.balanceOf(address(jackpot)), entryAmount);
        _assertEq(token.balanceOf(alice), 9_000 ether);
    }

    function testCanEnterManyTimesAndEveryEntryResetsTimer() public {
        vm.warp(100);
        _enter(alice);

        vm.warp(220);
        _enter(bob);

        vm.warp(300);
        _enter(alice);

        _assertEq(jackpot.leader(), alice);
        _assertEq(jackpot.pot(), 3_000 ether);
        _assertEq(jackpot.endsAt(), 300 + jackpotDuration);
    }

    function testWinnerClaimsExpiredJackpotAndStateResets() public {
        _enter(alice);
        _enter(bob);

        vm.warp(jackpot.endsAt());

        uint256 bobBalanceBefore = token.balanceOf(bob);
        vm.prank(bob);
        jackpot.claimPrize();

        _assertEq(jackpot.leader(), address(0));
        _assertEq(jackpot.lastWinner(), bob);
        _assertEq(jackpot.pot(), 0);
        _assertEq(jackpot.endsAt(), block.timestamp + jackpotDuration);
        _assertEq(token.balanceOf(bob), bobBalanceBefore + 2_000 ether);
        _assertEq(token.balanceOf(address(jackpot)), 0);
    }

    function testConfigChangesAffectNextEntryAfterClaim() public {
        _enter(alice);

        uint256 newEntryAmount = 2_500 ether;
        uint256 newDuration = 10 minutes;
        jackpot.setEntryAmount(newEntryAmount);
        jackpot.setJackpotDuration(newDuration);

        _enter(bob);

        _assertEq(jackpot.pot(), 2_000 ether);
        _assertEq(jackpot.endsAt(), block.timestamp + jackpotDuration);

        vm.warp(jackpot.endsAt());
        vm.prank(bob);
        jackpot.claimPrize();

        vm.warp(block.timestamp + 10);
        _enter(carol);

        _assertEq(jackpot.pot(), newEntryAmount);
        _assertEq(jackpot.endsAt(), block.timestamp + newDuration);
    }

    function testFeeOnTransferTokenAccountsForActualReceivedAmount() public {
        token.setFeeBps(500);
        _enter(alice);

        _assertEq(jackpot.pot(), 950 ether);
        _assertEq(token.balanceOf(address(jackpot)), 950 ether);
    }

    function testCannotEnterExpiredFundedJackpotBeforeWinnerClaims() public {
        _enter(alice);
        vm.warp(jackpot.endsAt());

        vm.prank(bob);
        vm.expectRevert(TokenEntryJackpot.JackpotExpired.selector);
        jackpot.enter();
    }

    function testExpiredEmptyJackpotRestartsOnEnter() public {
        vm.warp(jackpot.endsAt());
        _enter(alice);

        _assertEq(jackpot.leader(), alice);
        _assertEq(jackpot.pot(), entryAmount);
        _assertEq(jackpot.endsAt(), block.timestamp + jackpotDuration);
    }

    function testCannotClaimBeforeExpiry() public {
        _enter(alice);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.JackpotNotExpired.selector);
        jackpot.claimPrize();
    }

    function testOnlyLeaderCanClaim() public {
        _enter(alice);

        vm.warp(jackpot.endsAt());

        vm.prank(bob);
        vm.expectRevert(TokenEntryJackpot.NotWinner.selector);
        jackpot.claimPrize();
    }

    function testCannotClaimEmptyExpiredJackpot() public {
        vm.warp(jackpot.endsAt());

        vm.expectRevert(TokenEntryJackpot.NoPrize.selector);
        jackpot.claimPrize();
    }

    function testPauseBlocksEntriesButNotWinnerClaim() public {
        _enter(alice);
        jackpot.setPaused(true);

        vm.prank(bob);
        vm.expectRevert(TokenEntryJackpot.Paused.selector);
        jackpot.enter();

        vm.warp(jackpot.endsAt());
        uint256 aliceBalanceBefore = token.balanceOf(alice);

        vm.prank(alice);
        jackpot.claimPrize();

        _assertEq(token.balanceOf(alice), aliceBalanceBefore + entryAmount);
    }

    function testOnlyOwnerCanUpdateConfig() public {
        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NotOwner.selector);
        jackpot.setEntryAmount(2_000 ether);

        vm.prank(alice);
        vm.expectRevert(TokenEntryJackpot.NotOwner.selector);
        jackpot.setJackpotDuration(10 minutes);

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

    function _assertEq(uint256 actual, uint256 expected) private pure {
        require(actual == expected, "uint mismatch");
    }

    function _assertEq(address actual, address expected) private pure {
        require(actual == expected, "address mismatch");
    }
}
