// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.18;

/**
 *  @title A Raffle Contract
 *  @author zhenkun luo
 *  @notice This contract is for creating a sample raffle
 *  @dev Implements Chainlink VRFv2
 */
// evm can load log events
//CEI chech Effects Interactions 检查智能合约就是用这三部分
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

contract Raffle is VRFConsumerBaseV2, AutomationCompatibleInterface {
    error Raffle_NotEnoughEthSent();
    error Raffle_NotEnoughTimeToPass();
    error Raffle_WinnerTranferFail();
    error Raffle_NotOpen();
    error RAFFLE_UpKeepNotNeeded(uint256, RaffleState, uint256);
    //bool caculatingWinner 用来计算是否可以加入lottery
    enum RaffleState {
        OPEN, //0
        CACULATING //1
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev Duation of the lottery in seconds
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscribtionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_player;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_rafflestate;
    /**
     * Event
     */
    event EnteredRaffle(address indexed player);
    event WinnerPicked(address indexed Winner); //log
    event randomWordsRequest(uint256 indexed requestId);

    /**
     *   @notice 如果继承的合约有constructor 需要在当前合约给参数
     */
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscribtionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscribtionId = subscribtionId;
        i_callbackGasLimit = callbackGasLimit;
        s_rafflestate = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee,"")
        if (msg.value < i_entranceFee) {
            revert Raffle_NotEnoughEthSent();
        }
        if (s_rafflestate != RaffleState.OPEN) {
            revert Raffle_NotOpen();
        }
        s_player.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    // when the winner supposed to be picked
    /**
     * @dev 这个需要完成以下的条件
     * 1 . 时间间隔是否被满足
     * 2 RaffleState 是否是OPEN
     * 3 合约里面是否有ETH
     * 4 是否有玩家在里面
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = RaffleState.OPEN == s_rafflestate;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_player.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
        return (upkeepNeeded, "0x0");
    }

    //1 get ramdom number
    //2 use random number to pick up winner
    //3 be automatic called
    function performUpkeep(bytes calldata /* performData */) external override {
        //chech to see if enough time has passed
        (bool upkeedMeeded, ) = checkUpkeep("");
        if (!upkeedMeeded) {
            revert RAFFLE_UpKeepNotNeeded(
                address(this).balance,
                s_rafflestate,
                s_player.length
            );
        }

        s_rafflestate = RaffleState.CACULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gaslane
            i_subscribtionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit randomWordsRequest(requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_player.length;
        address payable winner = s_player[indexOfWinner];
        s_recentWinner = winner;
        s_rafflestate = RaffleState.OPEN;
        s_player = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle_WinnerTranferFail();
        }
        emit WinnerPicked(winner);
    }

    /**
     * Getter Function
     */
    function getEnterFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return (s_rafflestate);
    }

    function getPlayer(uint256 indexOfPlayer) public view returns (address) {
        return s_player[indexOfPlayer];
    }

    function getPlayerLength() public view returns (uint256) {
        return s_player.length;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
