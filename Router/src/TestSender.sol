// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IRouter.sol";

contract TestSender{

    address router;

    event InterchainResult(bool res);

    constructor(address _router){
        router = _router;
    }

    function sendProof(uint32 _dest, address _receipient, bytes calldata _proof, bytes32[] calldata _publicInputs) external payable{
        IRouter(router).interchainProof{value: msg.value}(_dest, _receipient, _proof, _publicInputs);
    }

    function handleInterchainRes(bool res) external{
        emit InterchainResult(res);
    }

    receive() payable external{}

    function destroy() external{
        selfdestruct(payable(msg.sender));
    }

}