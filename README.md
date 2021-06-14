# sec-rps

A rock-papers-scissors implementation on Solidity for the Security course at Universidad Austral

## Project context

This [link](https://blog.ippon.tech/creating-your-first-truffle-project-part-1-of-2/) explains essentially the project
structure.

## Project requirements

- We should be able to create multiple matches simultaneously
- For each match we only have two players
- Each match consists of only on play
- For each match the amount needed to play must be declared (should be paid in WEI)
- To join a match you must pay the same as player 1
- The winning player takes everything. If it's a draw they both take back what they bet
- A match must be cancelable by player 1 (the creating player)
- After a user made its play then the other player has a timeout to make the play

We **MUST** use [OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/) to get
both [Ownable](https://docs.openzeppelin.com/contracts/4.x/access-control#ownership-and-ownable)
and [SafeMath](https://docs.openzeppelin.com/contracts/4.x/utilities#api:math.adoc%23SafeMath)

## Useful links

- [Solidity basic structures and types](https://cryptozombies.io/es/lesson/1/chapter/2)
- [Solidity Events](https://cryptozombies.io/es/lesson/1/chapter/13)
- [Solidity Maps](https://cryptozombies.io/es/lesson/2/chapter/2)
- [Storage and memory explained](https://cryptozombies.io/es/lesson/2/chapter/7)
- [Ownable and OpenZeppelin](https://cryptozombies.io/es/lesson/3/chapter/2)
- [Only Owner](https://cryptozombies.io/es/lesson/3/chapter/3)
- [Time](https://cryptozombies.io/es/lesson/3/chapter/5)
- [View Functions](https://cryptozombies.io/es/lesson/3/chapter/10)
- [Using fors](https://cryptozombies.io/es/lesson/3/chapter/12)
- [Send vs Transfer](https://vomtom.at/solidity-send-vs-transfer/)

## Notes

- We don't have to store old matches. As soon as a match finishes we can discard it

## Happy Path

### Match Creation

- In order to create a game there must not be any other current games with the same bet
    - E.g.,: if I bet 1 wei and there are no current games then I create a new game. If another player subscribes a bet
      but for 2 wei then another match gets created.
- At this stage there is a new game that contains only a bet and the player1
    - Player 1 can delete this match as soon as no one subscribes to his game. This would delete the game
    - Matches must die after ten minutes (?) of its original creation

### Match Start

- Another player could be added as player 2 of that game, if that player subscribes the same amount of wei.
    - Once this happens the game status gets updated, and it cannot longer get deleted by any players.
    - An event must be created to notify the first player about the change of state in its game
    - We should be able to query the state of our games (maybe)
    - A timer starts forcing both players to play within that time.

### Making a play

- Plays are simple: you can either play PAPER, ROCK or SCISSORS.
    - After a play we emit an event and another timeout is created, now to two minutes. The other player must play
      within that time
    - Plays cannot be changed
    - After each play we must check if the game is over or not
    - If the game is over it's a matter of computing the winner

### Paying the players

- We must `transfer` the winning player the bet amount

## Demo

- Create a Factory contract with player 1

### Ownable Factory

- Deactivate the factory with the `updateOpenForGames` function set to false
- Try to create a game trying to `register`. It will not allow it
- Change to player2 and try to `register`. It will not allow it.
- As player2 try to `updateOpenForGames` to true. It will not allow it.
- Back to player1, open the factory (`updateOpenForGames` to true)

## Match Register

- As player1 `register` a game with just one wei. It will allow it
- As player2 try to `cancel` the game created by player one. The game key is the value passed to create it. It will not
  allow it
- As player1 try to `cancel` the game created by yourself. It will allow it
- As player1 `register` a game with just one wei. It will allow it
- As player 2 `register` a game one wei. It will create a new game. Look for the game address in the logs and connect to
  it. Remember to select the factory contract and use the `toAddress` feature, not the `Deploy` button.

## Match

- As player 3 try to make a `move` in the new Match. It will not allow it.
- As player 1 create a new `move`. Moves consist of a string that has first the Move ("r", "p", "s") and then your
  password. You must encode this move using [keccack256](https://emn178.github.io/online-tools/keccak_256.html) and pass
  it adding a "0x" at the beginning. Use "rMySecretPassword" as move.
- As player 1 try to repeat the move. It will not allow it.
- As player 1 try `revealMove` your move. Reveals consist of the decoded move string and the keccak of it. It will not
  allow it.
- As player 2 `move`, following the same steps than the player 1, but move "pMyOtherSecretPassword".
- As player 1 try to `revealMove` your move. It will allow it.
- As player 2 try to `revealMove` your move. It will allow it. This will output the result. It should be a player 2 win.