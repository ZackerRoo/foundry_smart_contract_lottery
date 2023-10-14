// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script, console} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscriptionId is Script {
    function createSubscriptUsingConfig() public returns (uint64) {
        HelperConfig helperconfig = new HelperConfig();
        (, , address vrfcoordinator, , , , , uint256 deployKey) = helperconfig
            .activateNetwork();
        return createSubscriptions(vrfcoordinator, deployKey);
    }

    function createSubscriptions(
        address vrfcoordinator,
        uint256 deployKey
    ) public returns (uint64) {
        console.log("creating subscribtions Id on", block.chainid);
        vm.startBroadcast(deployKey);
        uint64 subscribId = VRFCoordinatorV2Mock(vrfcoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("please update you sub ID", subscribId);
        return subscribId;
    }

    function run() external returns (uint64) {
        return createSubscriptUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscribtionUsingConfig() public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address ivrfCoordinator,
            ,
            uint64 subId,
            ,
            address linktoken,
            uint256 deployKey
        ) = helperconfig.activateNetwork();
        console.log("the subId", subId);
        fundSubscribtions(ivrfCoordinator, subId, linktoken, deployKey);
    }

    function fundSubscribtions(
        address ivrfCoordinator,
        uint64 subId,
        address linktoken,
        uint256 deployKey
    ) public {
        console.log("the ivrfCoordinator address is ", ivrfCoordinator);
        console.log("the subid is ", subId);
        console.log("On chain :", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployKey);
            VRFCoordinatorV2Mock(ivrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linktoken).transferAndCall(
                ivrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            ); //还有疑问
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscribtionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperconfig = new HelperConfig();
        (
            ,
            ,
            address ivrfCoordinator,
            ,
            uint64 subId,
            ,
            ,
            uint256 deployKey
        ) = helperconfig.activateNetwork();
        addConsumer(raffle, ivrfCoordinator, subId, deployKey);
    }

    function addConsumer(
        address raffle,
        address ivrfCoordinator,
        uint64 subId,
        uint256 deployKey
    ) public {
        console.log("adding consumer contract:", raffle);
        console.log("using vrfcoordinator:", ivrfCoordinator);
        console.log("subId is ", subId);
        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock(ivrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
