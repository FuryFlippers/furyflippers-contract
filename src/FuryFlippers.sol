// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract FuryFlippers is Ownable {
    address token;
    uint256 betLength;
    mapping(bytes32 => uint256) public active;

    event BetCreated(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 betId
    );

    event BetCancelled(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 betId
    );

    event BetTaken(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        address winner,
        uint256[] results,
        bytes32 betId
    );

    constructor(address _token, uint256 _betLength) {
        token = _token;
        betLength = _betLength;
    }

    function getBetId(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(maker, taker, makerHeads, amount));
    }

    function createBet(
        address taker,
        uint256 amount,
        bool makerHeads
    ) external {
        bytes32 betId = _createBet(taker, amount, makerHeads);
        emit BetCreated(msg.sender, taker, amount, makerHeads, betId);
    }

    function cancelBet(
        address taker,
        uint256 amount,
        bool makerHeads
    ) external {
        bytes32 betId = _cancelBet(taker, amount, makerHeads);
        emit BetCancelled(msg.sender, taker, amount, makerHeads, betId);
    }

    function takeBet(address maker, uint256 amount, bool makerHeads) external {
        (bytes32 betId, address winner, uint256[] memory results) = _takeBet(
            maker,
            amount,
            makerHeads
        );
        emit BetTaken(maker, msg.sender, amount, makerHeads, winner, results, betId);
    }

    function _createBet(
        address taker,
        uint256 amount,
        bool makerHeads
    ) internal returns (bytes32 betId) {
        betId = getBetId(msg.sender, taker, amount, makerHeads);
        require(active[betId] == 0, "exists");
        active[betId] = 1;
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
    }

    function _cancelBet(
        address taker,
        uint256 amount,
        bool makerHeads
    ) internal returns (bytes32 betId) {
        betId = getBetId(msg.sender, taker, amount, makerHeads);
        require(active[betId] == 1, "does not exist");
        active[betId] = 0;
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
    }

    function _takeBet(
        address maker,
        uint256 amount,
        bool makerHeads
    )
        internal
        returns (bytes32 betId, address winner, uint256[] memory results)
    {
        betId = getBetId(maker, msg.sender, amount, makerHeads);
        require(active[betId] == 1, "does not exist");
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.number, block.prevrandao))
        );
        uint256 makerScore = 0;
        uint256 takerScore = 0;
        uint256 i = 0;
        uint256 convertedSeed;
        while (i < betLength) {
            seed = uint256(keccak256(abi.encode(seed)));
            unchecked {
                convertedSeed = seed % 100;
                results[i] = convertedSeed;
                if (convertedSeed < 50) {
                    ++makerScore;
                } else {
                    ++takerScore;
                }
                ++i;
            }
        }
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
        if (makerScore > takerScore) {
            winner = maker;
            SafeTransferLib.safeTransfer(token, maker, amount * 2);
        } else {
            winner = msg.sender;
            SafeTransferLib.safeTransfer(token, msg.sender, amount * 2);
        }
    }
}