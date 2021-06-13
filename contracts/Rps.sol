// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract RPSFactory is Ownable {

    using SafeMath for uint;

    uint public BET_MIN = 1 wei;
    uint SECOND_PLAY_TIMEOUT = 1 minutes;
    uint FIRST_PLAY_TIMEOUT = 1 hours;

    bool openForNewGames = true;

    function updateOpenForGames(bool _openForGame) public onlyOwner {
        openForNewGames = _openForGame;
    }

    mapping(uint => OpenMatch) betToOpenMatch;
    RPSGame[] public matches;

    event OpenedMatch(OpenMatch openMatch);
    event OpenMatchCanceled(uint value);
    event MatchCreated(uint index, address game);

    modifier validBet() {
        require(msg.value >= BET_MIN, "Bet must be at least 1 wei");
        _;
    }

    modifier isOpenForGames() {
        require(openForNewGames, "Factory closed: not creating new games");
        _;
    }

    modifier isGameOwner(uint _value) {
        require(betToOpenMatch[_value].player1 == payable(msg.sender), "User is not the owner of the OpenGame");
        _;
    }

    constructor() Ownable(){}

    function register() public payable validBet isOpenForGames {
        if (betToOpenMatch[msg.value].bet != 0) {
            OpenMatch memory openMatch = betToOpenMatch[msg.value];
            uint index = matches.length;
            RPSGame newGame = new RPSGame(index, openMatch.player1, payable(msg.sender), block.timestamp + FIRST_PLAY_TIMEOUT, SECOND_PLAY_TIMEOUT, msg.value);
            payable(address(newGame)).transfer(msg.value.add(openMatch.bet));
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
    Outcomes public outcome;
    Moves public player1Move;
    Moves public player2Move;
    bytes32 public player1EncodedMove;
    bytes32 public player2EncodedMove;
    uint afterPlayTimeout;
    uint currentTimeout;
    GameStatus public status;

    event Result(Outcomes outcome);
    event CanceledMatch();

    modifier isPlayer() {
        require(msg.sender == player1 || msg.sender == player2, "You don't belong in this match");
        _;
    }

    modifier bothPlayed() {
        require(player1EncodedMove.length != 0 && player2EncodedMove.length != 0, "Both players must play before revealing");
        _;
    }

    modifier isActive() {
        require(status == GameStatus.Canceled);
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

    function move(bytes32 _move) public isPlayer isActive {
        if (!_timeoutValid()) {
            _cancelMatch();
            return;
        }
        if (msg.sender == player1) {
            require(player1EncodedMove == 0, "You have already played");
            player1EncodedMove = _move;
        }
        else {
            require(player2EncodedMove == 0, "You have already played");
            player2EncodedMove = _move;
        }
        currentTimeout = block.timestamp + afterPlayTimeout;
    }

    function revealMove(string memory _move, bytes32 _moveCommit) public isPlayer isActive {
        require(_moveCommit == keccak256(abi.encodePacked(_move)), "Move is not the committed one");
        if (payable(msg.sender) == player1) {
            require(player1EncodedMove == _moveCommit, "Commits are not equal");
            require(player1Move == Moves.None, "Player has already revealed move");
            bytes memory decodeMove = bytes(_move);
            player1Move = _moveToMove(decodeMove);
        } else {
            require(player2EncodedMove == _moveCommit, "Commits are not equal");
            require(player2Move == Moves.None, "Player has already revealed move");
            bytes memory decodeMove = bytes(_move);
            player2Move = _moveToMove(decodeMove);
        }
        outcome = _getOutcome();
        _handleOutcome();
        emit Result(outcome);
    }

    function _moveToMove(bytes memory _move) private pure returns (Moves){
        if(_move[0] == 'r'){
            return Moves.Rock;
        }
        if(_move[0] == 'p'){
            return Moves.Paper;
        }
        if(_move[0] == 's'){
            return Moves.Scissors;
        }
        return Moves.None;
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
