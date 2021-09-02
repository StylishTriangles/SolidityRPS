// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract RPS {
    enum HAND{ DEFAULT, ROCK, PAPER, SCISSORS }

    struct Bet {
        address player1;
        address player2;
        uint256 wager;
        uint64 deadline;
        HAND revealedHand1;
        HAND hand2;
    }

    mapping (uint => Bet) private bets;
    
    function newBet(bytes32 hashedHand) public payable {
        require(bets[uint256(hashedHand)].player1 == address(0), "This bet already exists");
        require(msg.value >= 0.0001 ether, "Wager too small");
        bets[uint256(hashedHand)] = Bet({
            player1: msg.sender,
            player2: address(0),
            wager: msg.value,
            deadline: uint64(block.timestamp + 1 days),
            revealedHand1: HAND.DEFAULT,
            hand2: HAND.DEFAULT
        });
    }

    function calculateBetHash(HAND h, bytes32 secret) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(h, secret));
    }

    function acceptBet(bytes32 betID, HAND h) public payable {
        Bet storage bet = bets[uint256(betID)];
        require(bet.player1 != address(0), "Bet has not been initialized yet");
        require(bet.player2 == address(0), "No more room in this bet");
        require(bet.wager == msg.value, "Wager must be matched");
        require(h != HAND.DEFAULT, "Invalid hand");
        bet.player2 = msg.sender;
        bet.hand2 = h;
    }

    function revealHand(bytes32 betID, HAND h, bytes32 secret) public {
        Bet storage bet = bets[uint256(betID)];
        require(bet.player1 == msg.sender, "Only player1 can reveal their hand");
        require(bet.player2 != address(0), "Bet has not been initialized yet");
        require(calculateBetHash(h, secret) == betID, "Secret and hand don't match the hash");
        bet.revealedHand1 = h;
    }
    
    function beats(HAND a, HAND b) private pure returns(bool) {
        return (a == HAND.ROCK && b == HAND.SCISSORS)
            || (a == HAND.SCISSORS && b == HAND.PAPER)
            || (a == HAND.PAPER && b == HAND.ROCK)
            || (b == HAND.DEFAULT && a != HAND.DEFAULT);
    }
    
    modifier isWinner(bytes32 betID) {
        Bet storage bet = bets[uint256(betID)];
        require(bet.player1 != address(0), "Bet isn't resolved");
        require(bet.player2 != address(0), "Bet isn't resolved");
        require(bet.revealedHand1 != HAND.DEFAULT, "Bet isn't resolved");
        require(bet.player1 == msg.sender || bet.player2 == msg.sender, "Only one of the players can be a winner");
        if (msg.sender == bet.player1) {
            require(beats(bet.revealedHand1, bet.hand2), "Not a winner");
        } else {
            require(beats(bet.hand2, bet.revealedHand1), "Not a winner");
        }
        _;
    }
    
    function withdraw(bytes32 betID) public isWinner(betID){
        Bet storage bet = bets[uint256(betID)];
        payable(msg.sender).transfer(bet.wager * 2);
        delete bets[uint256(betID)];
    }

    function claimDraw(bytes32 betID) public {
        Bet storage bet = bets[uint256(betID)];
        require(bet.revealedHand1 == bet.hand2, "It's not a draw");
        if (bet.player1 == msg.sender) {
            bet.player1 = address(0);
        } else if (bet.player2 == msg.sender) {
            bet.player2 = address(0);
        } else {
            revert();
        }
        payable(msg.sender).transfer(bet.wager);

        if (bet.player1 == address(0) && bet.player2 == address(0)) {
            delete bets[uint256(betID)];
        }
    }

    function claimUnrevealed(bytes32 betID) public {
        Bet storage bet = bets[uint256(betID)];
        require(bet.player2 == msg.sender, "Only player2 can claim");
        require(bet.deadline <= block.timestamp, "Bet hasn't expired");

        payable(msg.sender).transfer(bet.wager * 2);
        delete bets[uint256(betID)];
    }
}
