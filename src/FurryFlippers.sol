// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

contract FurryFlippers is Ownable {
    address public token;
    address public lottery;
    uint256 public fee;
    uint256 public betLength;
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
        uint256 lotteryFee,
        uint256 payout,
        bytes32 betId
    );

    constructor(
        address _token,
        address _lottery,
        uint256 _fee,
        uint256 _betLength
    ) {
        token = _token;
        lottery = _lottery;
        fee = _fee;
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

    function takeBet(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads
    ) external {
        (
            bytes32 betId,
            address winner,
            uint256[] memory results,
            uint256 lotteryFee,
            uint256 payout
        ) = _takeBet(maker, taker, amount, makerHeads);
        emit BetTaken(
            maker,
            msg.sender,
            amount,
            makerHeads,
            winner,
            results,
            lotteryFee,
            payout,
            betId
        );
    }

    function changeLotteryAddress(address newLottery) external onlyOwner {
        lottery = newLottery;
    }

    function changeLotteryFee(uint256 newFee) external onlyOwner {
        fee = newFee;
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
        address taker,
        uint256 amount,
        bool makerHeads
    )
        internal
        returns (
            bytes32 betId,
            address winner,
            uint256[] memory results,
            uint256 lotteryFee,
            uint256 payout
        )
    {
        if (taker == address(0)) {
            betId = getBetId(maker, taker, amount, makerHeads);
        } else {
            betId = getBetId(maker, msg.sender, amount, makerHeads);
        }
        require(active[betId] == 1, "does not exist");
        uint256 seed = uint256(
            keccak256(abi.encodePacked(block.number, block.prevrandao))
        );
        uint256 makerScore;
        uint256 takerScore;
        uint256 i;
        uint256 convertedSeed;
        results = new uint256[](betLength);
        while (i < betLength) {
            seed = uint256(keccak256(abi.encode(seed)));
            unchecked {
                convertedSeed = seed % 2;
                results[i] = convertedSeed;
                if (convertedSeed == 0) {
                    ++makerScore;
                } else {
                    ++takerScore;
                }
                ++i;
            }
        }
        active[betId] = 0;
        if (makerScore > takerScore) {
            winner = maker;
        } else {
            winner = msg.sender;
        }
        unchecked {
            payout = amount * 2;
            lotteryFee = (payout * fee) / 10000;
            payout = payout - lotteryFee;
        }
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
        SafeTransferLib.safeTransfer(token, lottery, lotteryFee);
        SafeTransferLib.safeTransfer(token, winner, payout);
    }
}
