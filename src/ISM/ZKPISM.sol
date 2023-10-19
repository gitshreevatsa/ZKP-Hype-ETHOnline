// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./AbstractZKPISM.sol";

contract ZKPISM is AbstractZKPISM{

    constructor(address _baseISM){
        baseISM = _baseISM;
    }

}