// SPDX-License-Identifier:MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelperConfig is Script {
    struct NetWorkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscribtionId;
        uint32 callbackGasLimit;
        address linktoken;
        uint256 deployKey;
    }
    NetWorkConfig public activateNetwork;
    uint256 private constant DefaultKey =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activateNetwork = getSepoliaNetworkConfig();
        } else {
            activateNetwork = getLocalAnvilEthConfig();
        }
    }

    function getSepoliaNetworkConfig() public returns (NetWorkConfig memory) {
        return
            NetWorkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscribtionId: 5878, //update this with our
                callbackGasLimit: 500000,
                linktoken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
                deployKey: vm.envUint("Private_key")
            });
    }

    function getLocalAnvilEthConfig() public returns (NetWorkConfig memory) {
        if (activateNetwork.vrfCoordinator != address(0)) {
            return activateNetwork;
        }
        uint96 baseGas = 0.25 ether; //link
        uint96 GasPriceLink = 1e9; //gwei
        // vm.startBroadcast();
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock(
            baseGas,
            GasPriceLink
        );
        LinkToken linktokens = new LinkToken();
        // vm.stopBroadcast();
        return
            NetWorkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: address(vrfCoordinatorV2Mock),
                gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
                subscribtionId: 0, //update this with our
                callbackGasLimit: 500000,
                linktoken: address(linktokens),
                deployKey: DefaultKey
            });
    }
}
