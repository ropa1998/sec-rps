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
    event OpenedMatch(OpenMatch openMatch);
    event CanceledMatch(uint value);

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

    modifier isGameOwner(uint _value) {
        require(betToOpenMatch[_value].player1 == payable(msg.sender));
        _;
    }


    function register() public payable validBet {
        if (betToOpenMatch[msg.value].bet != 0){
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            ReadyMatch memory readyMatch = ReadyMatch(openMatch.player1, payable(msg.sender), msg.value, Outcomes.None, Moves.None, Moves.None);
            idToReadyMatch[counter] = readyMatch;
            emit MatchIsReady(counter, readyMatch.player1, readyMatch.player2);
            counter++;
            delete betToOpenMatch[msg.value];
        }
        else {
            OpenMatch memory openMatch = OpenMatch(payable(msg.sender), msg.value);
            betToOpenMatch[msg.value] = openMatch;
            emit OpenedMatch(openMatch);
        }
    }

    function cancel(uint _value) public isGameOwner(_value){
        OpenMatch memory om = betToOpenMatch[_value];
        om.player1.transfer(om.bet);
        delete betToOpenMatch[_value];
        emit CanceledMatch(_value);
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
        ReadyMatch memory readyMatch = idToReadyMatch[_readyMatchId];
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
        idToReadyMatch[_readyMatchId] = readyMatch;
        emit Result(outcome, readyMatch.player1, readyMatch.player2);
    }

    function _getOutcome(ReadyMatch memory _match) private view returns (Outcomes) {
        if (_isMatchFinished(_match)){
            return resultHandler[_match.player1Move][_match.player2Move];
        }
        return Outcomes.None;
    }

    function _isMatchFinished(ReadyMatch memory _match) private pure returns (bool) {
        return (_match.player1Move != Moves.None && _match.player2Move != Moves.None);
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
