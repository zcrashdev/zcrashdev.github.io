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
    error JackpotExpired();
    error JackpotNotExpired();
    error NoPrize();
    error NotWinner();
    error InvalidAmount();
    error InvalidDuration();
    error TransferFailed();
    error ReentrantCall();
    error NoTokensReceived();

    IERC20 public immutable token;
    address public owner;
    address public leader;
    address public lastWinner;
    uint256 public entryAmount;
    uint256 public jackpotDuration;
    uint256 public endsAt;
    uint256 public pot;
    bool public paused;
    bool private locked;

    event Entered(address indexed player, uint256 amount, uint256 pot, uint256 endsAt);
    event PrizeClaimed(address indexed winner, uint256 amount);
    event EntryAmountUpdated(uint256 entryAmount);
    event JackpotDurationUpdated(uint256 jackpotDuration);
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

    constructor(address token_, uint256 entryAmount_, uint256 jackpotDuration_) {
        if (token_ == address(0) || entryAmount_ == 0) revert InvalidAmount();
        if (jackpotDuration_ == 0) revert InvalidDuration();

        token = IERC20(token_);
        owner = msg.sender;
        entryAmount = entryAmount_;
        jackpotDuration = jackpotDuration_;
        endsAt = block.timestamp + jackpotDuration_;

        emit OwnershipTransferred(address(0), msg.sender);
    }

    function enter() external whenNotPaused nonReentrant {
        if (block.timestamp >= endsAt && pot > 0) revert JackpotExpired();
        if (block.timestamp >= endsAt && pot == 0) {
            endsAt = block.timestamp + jackpotDuration;
        }

        uint256 balanceBefore = token.balanceOf(address(this));
        _safeTransferFrom(msg.sender, address(this), entryAmount);
        uint256 received = token.balanceOf(address(this)) - balanceBefore;
        if (received == 0) revert NoTokensReceived();

        leader = msg.sender;
        pot += received;
        endsAt = block.timestamp + jackpotDuration;

        emit Entered(msg.sender, received, pot, endsAt);
    }

    function claimPrize() external nonReentrant {
        if (block.timestamp < endsAt) revert JackpotNotExpired();
        if (pot == 0) revert NoPrize();
        if (msg.sender != leader) revert NotWinner();

        uint256 amount = pot;
        address winner = msg.sender;

        pot = 0;
        leader = address(0);
        lastWinner = winner;
        endsAt = block.timestamp + jackpotDuration;

        emit PrizeClaimed(winner, amount);
        _safeTransfer(winner, amount);
    }

    function setEntryAmount(uint256 entryAmount_) external onlyOwner {
        if (entryAmount_ == 0) revert InvalidAmount();
        entryAmount = entryAmount_;
        emit EntryAmountUpdated(entryAmount_);
    }

    function setJackpotDuration(uint256 jackpotDuration_) external onlyOwner {
        if (jackpotDuration_ == 0) revert InvalidDuration();
        jackpotDuration = jackpotDuration_;
        emit JackpotDurationUpdated(jackpotDuration_);
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
