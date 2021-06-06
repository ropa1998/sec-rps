// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract rps {

    uint public BET_MIN = 1 wei;
    uint counter = 1;

    enum Moves {None, Rock, Paper, Scissors}
    enum Outcomes {None, Player1, Player2, Draw}
    mapping(uint => OpenMatch) betToOpenMatch;
    mapping(uint => ReadyMatch) idToReadyMatch;
    mapping(Moves => mapping(Moves => Outcomes)) resultHandler;

    event MatchIsReady(uint readyMatchId, address payable player1, address payable player2);
    event Result(Outcomes outcome, address payable player1, address payable player2);

    constructor() {
        resultHandler[Moves.Rock][Moves.Rock] = Outcomes.Draw;
        resultHandler[Moves.Rock][Moves.Paper] = Outcomes.Player2;
        resultHandler[Moves.Rock][Moves.Scissors] = Outcomes.Player1;
        resultHandler[Moves.Paper][Moves.Rock] = Outcomes.Player1;
        resultHandler[Moves.Paper][Moves.Paper] = Outcomes.Draw;
        resultHandler[Moves.Paper][Moves.Scissors] = Outcomes.Player2;
        resultHandler[Moves.Scissors][Moves.Rock] = Outcomes.Player2;
        resultHandler[Moves.Scissors][Moves.Paper] = Outcomes.Player1;
        resultHandler[Moves.Scissors][Moves.Scissors] = Outcomes.Draw;
    }

    modifier validBet() {
        require(msg.value >= BET_MIN);
        _;
    }

    function register() public payable validBet returns (uint) {
        if (betToOpenMatch[msg.value].bet != 0){
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            ReadyMatch memory readyMatch = ReadyMatch(openMatch.player1, msg.sender, msg.value, Outcomes.None, Moves.None, Moves.None);
            idToReadyMatch[counter] = readyMatch;
            emit MatchIsReady(counter, readyMatch.player1, readyMatch.player2);
            counter++;
            delete betToOpenMatch[msg.value];
            return counter - 1;
        }
        else {
            OpenMatch memory openMatch = OpenMatch(msg.sender, msg.value);
            betToOpenMatch[msg.value] = openMatch;
            return 0;
        }
    }

    struct OpenMatch {
        address payable player1;
        uint bet;
    }

    struct ReadyMatch {
        address payable player1;
        address payable player2;
        uint bet;
        Outcomes outcome;
        Moves player1Move;
        Moves player2Move;
    }

    function move(Moves _move, uint _readyMatchId) public {
        ReadyMatch storage readyMatch = idToReadyMatch[_readyMatchId];
        require(msg.sender == readyMatch.player1 || msg.sender == readyMatch.player2);
        if (msg.sender == readyMatch.player1) {
            require(readyMatch.player1Move == Moves.None);
            readyMatch.player1Move = _move;
        }
        else {
            require(readyMatch.player2Move == Moves.None);
            readyMatch.player2Move = _move;
        }
        Outcomes outcome = _getOutcome(readyMatch);
        readyMatch.outcome = outcome;
        emit Result(outcome, readyMatch.player1, readyMatch.player2);
    }

    function _getOutcome(ReadyMatch memory _match) private isMatchFinished(_match) returns (Outcomes) {
        return resultHandler[_match.player1Move][_match.player2Move];
    }

    modifier isMatchFinished(ReadyMatch memory _match) {
        require(_match.player1Move != Moves.None && _match.player2Move != Moves.None);
        _;
    }

    function _handleOutcome(ReadyMatch memory _match) private {
        if (_match.outcome == Outcomes.Player1) {
            _match.player1.transfer(_match.bet * 2);
        }
        if (_match.outcome == Outcomes.Player2) {
            _match.player2.transfer(_match.bet * 2);
        }
    }


}
