// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

contract TokenEntryJackpot {
    error NotOwner();
    error Paused();
    error RoundActive();
    error RoundExpired();
    error RoundNotExpired();
    error RoundAlreadyFinalized();
    error PrizeAlreadyClaimed();
    error NotWinner();
    error InvalidAmount();
    error InvalidDuration();
    error TransferFailed();
    error ReentrantCall();
    error NoTokensReceived();

    struct Round {
        address leader;
        address winner;
        uint256 pot;
        uint256 entryAmount;
        uint256 roundDuration;
        uint256 endsAt;
        bool finalized;
        bool claimed;
    }

    IERC20 public immutable token;
    address public owner;
    uint256 public entryAmount;
    uint256 public roundDuration;
    uint256 public currentRoundId;
    bool public paused;
    bool private locked;

    mapping(uint256 => Round) public rounds;

    event Entered(
        uint256 indexed roundId,
        address indexed player,
        uint256 amount,
        uint256 pot,
        uint256 endsAt
    );
    event RoundFinalized(uint256 indexed roundId, address indexed winner, uint256 pot);
    event PrizeClaimed(uint256 indexed roundId, address indexed winner, uint256 amount);
    event NextRoundStarted(uint256 indexed roundId, uint256 endsAt);
    event EntryAmountUpdated(uint256 entryAmount);
    event RoundDurationUpdated(uint256 roundDuration);
    event PausedSet(bool paused);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Paused();
        _;
    }

    modifier nonReentrant() {
        if (locked) revert ReentrantCall();
        locked = true;
        _;
        locked = false;
    }

    constructor(address token_, uint256 entryAmount_, uint256 roundDuration_) {
        if (token_ == address(0) || entryAmount_ == 0) revert InvalidAmount();
        if (roundDuration_ == 0) revert InvalidDuration();

        token = IERC20(token_);
        owner = msg.sender;
        entryAmount = entryAmount_;
        roundDuration = roundDuration_;
        currentRoundId = 1;
        rounds[currentRoundId].entryAmount = entryAmount_;
        rounds[currentRoundId].roundDuration = roundDuration_;
        rounds[currentRoundId].endsAt = block.timestamp + roundDuration_;

        emit OwnershipTransferred(address(0), msg.sender);
        emit NextRoundStarted(currentRoundId, rounds[currentRoundId].endsAt);
    }

    function enter() external whenNotPaused nonReentrant {
        Round storage round = rounds[currentRoundId];
        if (round.finalized) revert RoundAlreadyFinalized();
        if (block.timestamp >= round.endsAt) revert RoundExpired();

        uint256 balanceBefore = token.balanceOf(address(this));
        _safeTransferFrom(msg.sender, address(this), round.entryAmount);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert NoTokensReceived();

        round.leader = msg.sender;
        round.pot += received;
        round.endsAt = block.timestamp + round.roundDuration;

        emit Entered(currentRoundId, msg.sender, received, round.pot, round.endsAt);
    }

    function finalizeRound() external {
        Round storage round = rounds[currentRoundId];
        if (round.finalized) revert RoundAlreadyFinalized();
        if (block.timestamp < round.endsAt) revert RoundNotExpired();

        round.finalized = true;
        round.winner = round.leader;

        emit RoundFinalized(currentRoundId, round.winner, round.pot);
    }

    function claimPrize(uint256 roundId) external nonReentrant {
        Round storage round = rounds[roundId];
        if (!round.finalized) revert RoundNotExpired();
        if (round.claimed) revert PrizeAlreadyClaimed();
        if (msg.sender != round.winner) revert NotWinner();

        uint256 amount = round.pot;
        round.claimed = true;
        round.pot = 0;

        if (amount > 0) {
            _safeTransfer(msg.sender, amount);
        }

        emit PrizeClaimed(roundId, msg.sender, amount);
    }

    function startNextRound() external whenNotPaused {
        Round storage current = rounds[currentRoundId];
        if (!current.finalized) revert RoundActive();

        currentRoundId += 1;
        rounds[currentRoundId].entryAmount = entryAmount;
        rounds[currentRoundId].roundDuration = roundDuration;
        rounds[currentRoundId].endsAt = block.timestamp + roundDuration;

        emit NextRoundStarted(currentRoundId, rounds[currentRoundId].endsAt);
    }

    function setEntryAmount(uint256 entryAmount_) external onlyOwner {
        if (entryAmount_ == 0) revert InvalidAmount();
        entryAmount = entryAmount_;
        emit EntryAmountUpdated(entryAmount_);
    }

    function setRoundDuration(uint256 roundDuration_) external onlyOwner {
        if (roundDuration_ == 0) revert InvalidDuration();
        roundDuration = roundDuration_;
        emit RoundDurationUpdated(roundDuration_);
    }

    function setPaused(bool paused_) external onlyOwner {
        paused = paused_;
        emit PausedSet(paused_);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert InvalidAmount();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function _safeTransfer(address to, uint256 amount) private {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }

    function _safeTransferFrom(address from, address to, uint256 amount) private {
        (bool success, bytes memory data) = address(token).call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, amount)
        );
        if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
            revert TransferFailed();
        }
    }
}
