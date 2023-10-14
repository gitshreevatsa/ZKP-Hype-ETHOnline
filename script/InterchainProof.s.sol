// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/Router.sol";
import "../src/interfaces/IRouter.sol";
import "../src/TestSender.sol";

contract InterchainProofContract is Script{

    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        address routerAddress = 0x37733D21BE60c4C6Ad03d297d90e03AbE4c9dD92;
        string memory proof = vm.readLine("circuit.proof");
        bytes memory proofBytes = vm.parseBytes(proof);
        bytes32[] memory publicInputs = new bytes32[](1);
        publicInputs[0] = bytes32(0x0000000000000000000000000000000000000000000000000000000000000005);
        TestSender mySender = new TestSender(routerAddress);
        mySender.sendProof(534353, 0x2A67Cf654F8EE1660639938BE9f3e30522A443b6, proofBytes, publicInputs);
        vm.stopBroadcast();
    }

}