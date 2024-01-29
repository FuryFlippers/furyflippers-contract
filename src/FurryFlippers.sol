// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {IEntropy} from "./interfaces/IEntropy.sol";

contract FurryFlippers is Ownable {
    address public token;
    address public lottery;
    IEntropy public entropy;
    address public entropyProvider;
    uint256 public fee;
    uint256 public betLength;

    mapping(bytes32 => betInformation) public bets;

    struct betInformation {
        uint96 active;
        uint96 locked;
        uint64 sequenceNumber;
    }

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
        bytes32 betId
    );

    event BetSettled(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 userRandom,
        bytes32 providerRandom,
        address winner,
        uint256[] results,
        uint256 lotteryFee,
        uint256 payout,
        bytes32 betId
    );

    constructor(
        address _token,
        address _lottery,
        address _entropy,
        address _entropyProvider,
        uint256 _fee,
        uint256 _betLength
    ) {
        token = _token;
        lottery = _lottery;
        entropy = IEntropy(_entropy);
        entropyProvider = _entropyProvider;
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

    function getEntropyFee() public view returns (uint256) {
        return entropy.getFee(entropyProvider);
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
        bytes32 betId = _takeBet(maker, amount, makerHeads);
        emit BetTaken(maker, msg.sender, amount, makerHeads, betId);
    }

    function settleBet(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 userRandom,
        bytes32 providerRandom
    ) external {
        (
            bytes32 betId,
            address winner,
            uint256[] memory results,
            uint256 lotteryFee,
            uint256 payout
        ) = _settleBet(
                maker,
                taker,
                amount,
                makerHeads,
                userRandom,
                providerRandom
            );
        emit BetSettled(
            maker,
            taker,
            amount,
            makerHeads,
            userRandom,
            providerRandom,
            winner,
            results,
            lotteryFee,
            payout,
            betId
        );
    }

    function requestSeed(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 commitment
    ) external payable {
        bytes32 betId = getBetId(maker, taker, amount, makerHeads);
        betInformation storage bet = bets[betId];
        require(bet.active == 1, "not active");
        require(bet.locked == 1, "not locked");
        require(bet.sequenceNumber != 0, "number already requested");
        uint256 entropyFee = entropy.getFee(entropyProvider);
        require(msg.value > entropyFee, "insufficient fee");
        uint64 sequenceNumber = entropy.request{value: entropyFee}(
            entropyProvider,
            commitment,
            true
        );
        bets[betId].sequenceNumber = sequenceNumber;
    }

    function changeParams(
        address _token,
        address _lottery,
        address _entropy,
        address _entropyProvider,
        uint256 _fee,
        uint256 _betLength
    ) external onlyOwner {
        token = _token;
        lottery = _lottery;
        entropy = IEntropy(_entropy);
        entropyProvider = _entropyProvider;
        fee = _fee;
        betLength = _betLength;
    }

    function _createBet(
        address taker,
        uint256 amount,
        bool makerHeads
    ) internal returns (bytes32 betId) {
        betId = getBetId(msg.sender, taker, amount, makerHeads);
        require(bets[betId].active == 0, "already active");
        bets[betId].active = 1;
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
        betInformation storage bet = bets[betId];
        require(bet.active == 1, "not active");
        require(bet.locked == 0, "already locked");
        bets[betId].active = 0;
        SafeTransferLib.safeTransfer(token, msg.sender, amount);
    }

    function _takeBet(
        address maker,
        uint256 amount,
        bool makerHeads
    ) internal returns (bytes32 betId) {
        betId = getBetId(maker, msg.sender, amount, makerHeads);
        betInformation storage bet = bets[betId];
        require(bet.active == 1, "not active");
        require(bet.locked == 0, "already locked");
        bets[betId].locked = 1;
        SafeTransferLib.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amount
        );
    }

    function _settleBet(
        address maker,
        address taker,
        uint256 amount,
        bool makerHeads,
        bytes32 userRandom,
        bytes32 providerRandom
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
        betId = getBetId(maker, taker, amount, makerHeads);
        require(bets[betId].sequenceNumber != 0, "number not requested");
        uint256 seed = uint256(
            entropy.reveal(
                entropyProvider,
                bets[betId].sequenceNumber,
                userRandom,
                providerRandom
            )
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
        delete bets[betId];
        SafeTransferLib.safeTransfer(token, lottery, lotteryFee);
        SafeTransferLib.safeTransfer(token, winner, payout);
    }
}
