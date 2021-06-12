// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract RPSFactory {

    uint public BET_MIN = 1 wei;
    uint SECOND_PLAY_TIMEOUT = 1 minutes;
    uint FIRST_PLAY_TIMEOUT = 1 hours;

    mapping(uint => OpenMatch) betToOpenMatch;
    RPSGame[] public matches;

    event OpenedMatch(OpenMatch openMatch);
    event OpenMatchCanceled(uint value);
    event MatchCreated(uint index, address game);

    modifier validBet() {
        require(msg.value >= BET_MIN);
        _;
    }

    modifier isGameOwner(uint _value) {
        require(betToOpenMatch[_value].player1 == payable(msg.sender));
        _;
    }

    function register() public payable validBet {
        if (betToOpenMatch[msg.value].bet != 0) {
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            uint index = matches.length;
            RPSGame newGame = new RPSGame(index, openMatch.player1, payable(msg.sender), block.timestamp + FIRST_PLAY_TIMEOUT, SECOND_PLAY_TIMEOUT, msg.value);
            payable(address(newGame)).transfer(msg.value*2);
            matches.push(newGame);
            emit MatchCreated(index, address(newGame));
            delete betToOpenMatch[msg.value];
        }
        else {
            OpenMatch memory openMatch = OpenMatch(payable(msg.sender), msg.value);
            betToOpenMatch[msg.value] = openMatch;
            emit OpenedMatch(openMatch);
        }
    }

    function cancel(uint _value) public isGameOwner(_value) {
        OpenMatch memory om = betToOpenMatch[_value];
        om.player1.transfer(om.bet);
        delete betToOpenMatch[_value];
        emit OpenMatchCanceled(_value);
    }

    struct OpenMatch {
        address payable player1;
        uint bet;
    }

}

contract RPSGame {

    uint public index;

    enum GameStatus {Active, Canceled, Finished}
    enum Moves {None, Rock, Paper, Scissors}
    enum Outcomes {None, Player1, Player2, Draw}
    mapping(Moves => mapping(Moves => Outcomes)) resultHandler;

    address payable player1;
    address payable player2;
    uint bet;
    Outcomes outcome;
    Moves player1Move;
    Moves player2Move;
    uint afterPlayTimeout;
    uint currentTimeout;
    GameStatus status;

    event Result(Outcomes outcome);
    event CanceledMatch();

    modifier isPlayer() {
        require(msg.sender == player1 || msg.sender == player2);
        _;
    }

    modifier isActive() {
        require(status != GameStatus.Canceled);
        _;
    }

    constructor(uint _index, address payable _player1, address payable _player2, uint _initialTimeout, uint _afterPlayTimeout, uint _bet){
        index = _index;
        player1 = _player1;
        player2 = _player2;
        currentTimeout = _initialTimeout;
        afterPlayTimeout = _afterPlayTimeout;
        bet = _bet;
        outcome = Outcomes.None;
        player1Move = Moves.None;
        player2Move = Moves.None;
        status = GameStatus.Active;
        createHandler();
    }

    function createHandler() private {
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

    fallback() external payable {}

    receive() external payable {}

    function move(Moves _move) public isPlayer {
        if (!_timeoutValid()) {
            _cancelMatch();
            return;
        }
        if (msg.sender == player1) {
            require(player1Move == Moves.None);
            player1Move = _move;
        }
        else {
            require(player2Move == Moves.None);
            player2Move = _move;
        }
        currentTimeout = block.timestamp + afterPlayTimeout;
        outcome = _getOutcome();
        _handleOutcome();
        emit Result(outcome);
    }

    function _getOutcome() private view returns (Outcomes) {
        if (_isMatchFinished()) {
            return resultHandler[player1Move][player2Move];
        }
        return Outcomes.None;
    }

    function _isMatchFinished() private view returns (bool) {
        return (player1Move != Moves.None && player2Move != Moves.None);
    }

    function _handleOutcome() private {
        if (outcome == Outcomes.Player1) {
            player1.transfer(bet * 2);
        }
        if (outcome == Outcomes.Player2) {
            player2.transfer(bet * 2);
        }
        if (outcome == Outcomes.Draw) {
            player2.transfer(bet);
            player1.transfer(bet);
        }
        status = GameStatus.Finished;
    }

    function _timeoutValid() view private returns (bool){
        return block.timestamp <= currentTimeout;
    }

    function _cancelMatch() private {
        player1.transfer(bet);
        player2.transfer(bet);
        status = GameStatus.Canceled;
        emit CanceledMatch();
    }
}
