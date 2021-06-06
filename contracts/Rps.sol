// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract rps {

    uint public BET_MIN = 1 wei;

    enum Moves {None, Rock, Paper, Scissors}
    enum Outcomes {None, Player1, Player2, Draw}
    mapping(uint => OpenMatch) betToOpenMatch;

    ReadyMatch[] readyMatches;

    modifier validBet() {
        require(msg.value >= BET_MIN);
        _;
    }

    function register() public payable validBet {
        if (betToOpenMatch[msg.value].bet != 0){
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            ReadyMatch memory readyMatch = ReadyMatch(openMatch.player1, msg.sender, msg.value);
            readyMatches.push(readyMatch);
            delete betToOpenMatch[msg.value];
        }
        else {
            OpenMatch memory openMatch = OpenMatch({player1: msg.sender, bet: msg.value});
            betToOpenMatch[msg.value] = openMatch;
        }
    }

    struct OpenMatch {
        address player1;
        uint bet;
    }

    struct ReadyMatch {
        address player1;
        address player2;
        uint bet;
    }


}
