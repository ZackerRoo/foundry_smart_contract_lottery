//SPDX license identifier:MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscriptionId, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entranceFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscribtionId,
            uint32 callbackGasLimit,
            address linktoken,
            uint256 deployKey
        ) = helperConfig.activateNetwork();
        // vm.startBroadcast(); //这两行的出现就代表会有交易出现

        if (subscribtionId == 0) {
            //create subscribtionId

            CreateSubscriptionId createSubscriptionId = new CreateSubscriptionId();
            subscribtionId = createSubscriptionId.createSubscriptions(
                vrfCoordinator,
                deployKey
            );
            // fund it
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscribtions(
                vrfCoordinator,
                subscribtionId,
                linktoken,
                deployKey
            );
        }
        vm.startBroadcast();
        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscribtionId,
            callbackGasLimit
        );
        vm.stopBroadcast();
        AddConsumer addconsumer = new AddConsumer();
        addconsumer.addConsumer(
            address(raffle),
            vrfCoordinator,
            subscribtionId,
            deployKey
        );
        return (raffle, helperConfig);
    }
}
