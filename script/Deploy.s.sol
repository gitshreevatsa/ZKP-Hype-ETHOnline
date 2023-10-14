// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Router.sol";
import "../src/interfaces/IRouter.sol";

contract RouterDeploy is Script {
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        //Use the below two lines to deploy the router on L1
        Router myRouter = new Router(0xCC737a94FecaeC165AbCf12dED095BB13F037685, 0xF90cB82a76492614D07B82a7658917f3aC811Ac1);
        myRouter.addRemote(534353, 0x335A3359024b959df5C7e6a7D994236E604958bA);
        // Comment the above two lines and uncomment the below line to deploy the router onto L2
        //Router myRouter = new Router(0xFA9d7C3C5ab6A78006b43182AD87D80aeBB8efDf, 0xAD58458d90694c0FC8cE462945bF09960426A7F5);
        //console.log("Router address for the given chain is :- ", address(myRouter));
        vm.stopBroadcast();
    }
}
