// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract rps {

    uint public BET_MIN = 1 wei;

    enum Moves {None, Rock, Paper, Scissors}
    enum Outcomes {None, Player1, Player2, Draw}

    OpenMatch[] openMatches;

    modifier validBet() {
        require(msg.value >= BET_MIN);
        _;
    }

    function register() public payable validBet returns (uint) {
        OpenMatch memory openMatch = OpenMatch({player1: msg.sender, bet: msg.value});
        openMatches.push(openMatch);
        return 1;
    }

    struct OpenMatch {
        address player1;
        uint bet;
    }


}