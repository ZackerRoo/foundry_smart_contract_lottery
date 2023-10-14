pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperconfig;
    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscribtionId;
    uint32 callbackGasLimit;
    address linktoken;
    uint256 deployKey;

    event EnteredRaffle(address indexed player);
    address public player = makeAddr("player");
    uint256 public constant START_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperconfig) = deployRaffle.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscribtionId,
            callbackGasLimit,
            ,

        ) = helperconfig.activateNetwork();
        vm.deal(player, START_BALANCE);
    }

    modifier skipTest() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testRaffleInitializedInOpenState() public view {
        // assert(raffle.getRaffleState() == 0);
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN); //读取合约中的某个状态时候可以直接使用合约名称
    }

    function testRaffleRevertswhenYouDontPayEnough() public {
        //Arrange
        vm.prank(player);
        //Act
        vm.expectRevert(Raffle.Raffle_NotEnoughEthSent.selector);
        raffle.enterRaffle();

        //assert
    }

    function testRaffleRecordsPlayerWhenTheyEnter() public {
        //Arrange
        vm.prank(player);
        //Act
        raffle.enterRaffle{value: entranceFee}();
        address playerRecord = raffle.getPlayer(0);
        assert(playerRecord == player);
        //assert
    }

    function testEmitsEventOnEntrance() public {
        //Arrange
        vm.prank(player);
        //Act
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(player);
        raffle.enterRaffle{value: entranceFee}();

        //assert
    }

    function testcantenterwhenRaffleisCaculating() public {
        console.log("testing");
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_NotOpen.selector);
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testcheckUpkeep() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeep, ) = raffle.checkUpkeep("");

        assert(!upkeep); //如果 bool 为真，assert 会抛出异常，终止程序执行，并在控制台或日志中输出相应的错误消息。如果 bool 为假，assert 语句不会做任何事情，程序会继续正常执行
    }

    function testCheckUpkeepReturnsFalseIfRaffleNotOpen() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        //assert
        assert(upkeepNeeded == false);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);

        (bool CheckUpKeep, ) = raffle.checkUpkeep("");

        assert(CheckUpKeep == false);
    }

    function testCheckUpkeepReturnTrueWhenParametersAregood() public {}

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // Assert
        // console(upkeepNeeded);
        assert(raffleState == Raffle.RaffleState.CACULATING); //里面为true正常执行否则抛出异常
        assert(upkeepNeeded == false);
    }

    //performUpkeep
    function testPerformUpkeepCanOnlyRunIfcheckUpkeepIsTrue() public {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //act
        raffle.performUpkeep(""); //如果这一项可以运行就会通过test因为代码中有revert
    }

    function testPerformUpkeepRevertIfcheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayer = 0;
        Raffle.RaffleState raffleS = raffle.getRaffleState();
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.RAFFLE_UpKeepNotNeeded.selector,
                currentBalance,
                numPlayer,
                raffleS
            )
        );
        raffle.performUpkeep("");
    }

    modifier raffleEnterAndTimePass() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnterAndTimePass
        skipTest
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; //因为在performUpkeep里面有两个emit事件所以提取出来会有两个步骤存在

        Raffle.RaffleState rState = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rState) == 1);
    }

    //fullfilRandomWords 也就是Fuzz Test
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnterAndTimePass skipTest {
        vm.expectRevert("nonexistent request"); //这个里面返回的内容 要和我们源代码报错的内容一致
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    //total test
    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney()
        public
        raffleEnterAndTimePass
        skipTest
    {
        uint256 iindexOfplayer = 1;
        uint256 addtionalPeople = 5;
        for (uint256 i = iindexOfplayer; i < addtionalPeople + 1; i++) {
            address enterplayer = address(uint160(i));
            hoax(enterplayer, START_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 prize = entranceFee * 6;
        //请求随机数
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; //因为在performUpkeep里面有两个emit事件所以提取出来会有两个步骤存在

        uint256 previousTime = raffle.getTimestamp();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(uint256(raffle.getRaffleState()) == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getPlayerLength() == 0);
        assert(previousTime < raffle.getTimestamp());
        assert(
            raffle.getRecentWinner().balance ==
                START_BALANCE + prize - entranceFee //每个人都有捐钱所以要减去
        );
    }
}
