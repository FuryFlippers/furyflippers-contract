// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract FuryFlippers is Ownable {
    mapping(bytes32 => uint256) public active;

    event BetCreated(
        address maker,
        address taker,
        address token,
        uint256 amount,
        bytes32 betId,
        uint256 timestamp
    );

    event BetCancelled(
        address maker,
        address taker,
        address token,
        uint256 amount,
        bytes32 betId,
        uint256 timestamp
    );

    event BetConcluded(
        address maker,
        address taker,
        address token,
        uint256 amount,
        bytes32 betId,
        uint256 timestamp,
        address winner
    );

    function getBetId(
        address maker,
        address taker,
        address token,
        uint256 amount,
        uint256 timestamp
    ) public pure returns (bytes32) {
        return
            keccak256(abi.encodePacked(maker, taker, token, amount, timestamp));
    }

    function _createBet(
        address taker,
        address token,
        uint256 amount
    ) internal returns (bytes32 betId) {
        betId = getBetId(msg.sender, taker, token, amount, block.timestamp);
        require(active[betId] == 0, "bet exists");
        active[betId] = 1;
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
    }

    function createBet(address taker, address token, uint256 amount) external {
        bytes32 betId = _createBet(taker, token, amount);
        emit BetCreated(
            msg.sender,
            taker,
            token,
            amount,
            betId,
            block.timestamp
        );
    }

    function _cancelBet(
        address taker,
        address token,
        uint256 amount,
        uint256 timestamp
    ) internal returns (bytes32 betId) {
        betId = getBetId(msg.sender, taker, token, amount, timestamp);
        require(active[betId] == 1, "bet does not exist");
        active[betId] = 0;
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
    }

    function cancelBet(
        address taker,
        address token,
        uint256 amount,
        uint256 timestamp
    ) external {
        bytes32 betId = _cancelBet(taker, token, amount, timestamp);
        emit BetCancelled(msg.sender, taker, token, amount, betId, timestamp);
    }

    function _takeBet(
        address maker,
        address token,
        uint256 amount,
        uint256 timestamp
    ) internal returns (bytes32 betId, address winner) {
        betId = getBetId(maker, msg.sender, token, amount, timestamp);
        require(active[betId] == 1, "bet does not exist");
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.number, block.prevrandao))
        );
        uint256 result = seed % 100;

        if (result < 50) {
            winner = maker;
        } else {
            winner = msg.sender;
        }

        active[betId] = 0;
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
        SafeTransferLib.safeTransfer(token, winner, amount);
    }

    function takeBet(
        address maker,
        address token,
        uint256 amount,
        uint256 timestamp
    ) external {
        (bytes32 betId, address winner) = _takeBet(
            maker,
            token,
            amount,
            timestamp
        );
        emit BetConcluded(
            maker,
            msg.sender,
            token,
            amount,
            betId,
            timestamp,
            winner
        );
    }
}
