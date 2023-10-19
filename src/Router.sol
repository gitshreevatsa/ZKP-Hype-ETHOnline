// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@hyperlane-xyz/core/contracts/interfaces/IMailbox.sol";
import "@hyperlane-xyz/core/contracts/interfaces/IInterchainGasPaymaster.sol";

interface IVerifier{
    function verifyInputs(bytes calldata _proof, bytes32[] calldata _publicInputs) external view returns(bool _result);
}

interface IReceiver{
    function handleInterchainRes(bool res) external;
}

contract Router{

    IInterchainSecurityModule public interchainSecurityModule;

    struct ReceiverContext{
        bytes data;
        uint256 lastReceivedPacket;
        address recipient;
    }

    mapping(uint32 => address) remoteRouters;
    mapping(bytes => uint256) nonce;
    mapping(bytes => address) receiver;
    mapping(bytes => ReceiverContext) contexts;

    address mailbox;
    address interchainGasPaymaster;

    modifier onlyMailbox(){
        require(msg.sender == mailbox);
        _;
    }

    event SentResult(bytes32 indexed receiver, bytes data);
    event InterchainComputationRequested(bytes32 hash, uint256 origin, uint32 dest, address verifier, bytes proof, bytes32[] publicInputs);

    constructor(address _mailbox, address _interchainGasPaymaster){
        mailbox = _mailbox;
        interchainGasPaymaster = _interchainGasPaymaster;
    }

    function setInterchainSecurityModule(address _ism) external {
        interchainSecurityModule = IInterchainSecurityModule(_ism);
    }

    function addRemote(uint32 _dest, address _router) external{
        remoteRouters[_dest] = _router;
    }

    function interchainProof(uint32 _dest, address _receipient, bytes calldata _proof, bytes32[] calldata _publicInputs) external payable{
        bytes memory _data = abi.encode(_proof, _publicInputs);
        bytes memory nonceKey = abi.encode(_dest, _receipient);
        uint256 i=0;
        require(remoteRouters[_dest] != address(0), "No remote routers found !!!");
        bytes32 routerAddress = addressToBytes32(remoteRouters[_dest]);
        bytes32 startMessageId = IMailbox(mailbox).dispatch(_dest, routerAddress, abi.encode(1, nonce[nonceKey], 0, 0, abi.encode(_receipient)));
        // uint256 recursiveQuote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_dest, 1000000);
        // IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: recursiveQuote}(
        //     startMessageId,
        //     _dest,
        //     1000000,
        //     address(this)
        // );
        for(i=0; i<(_data.length/1700); i++){
            bytes32 recursiveMessageId = IMailbox(mailbox).dispatch(_dest, routerAddress, abi.encode(2, nonce[nonceKey], i, _data.length/1700, BytesLib.slice(_data, (i*1700), 1700)));
            // IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: recursiveQuote}(
            //     recursiveMessageId,
            //     _dest,
            //     1000000,
            //     address(this)
            // );
        }
        bytes32 messageId = IMailbox(mailbox).dispatch(_dest, routerAddress, abi.encode(2, nonce[nonceKey], i, _data.length/1700, BytesLib.slice(_data, (i*1700), (_data.length)-(i*1700))));
        // uint256 quote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_dest, 10000000);
        // IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: quote}(
        //     messageId,
        //     _dest,
        //     10000000,
        //     address(this)
        // );
        receiver[abi.encode(_dest, routerAddress, nonce[nonceKey])] = msg.sender;
        nonce[nonceKey]++;
        emit InterchainComputationRequested(keccak256(abi.encode(_proof, _publicInputs, _receipient)), block.chainid, _dest, _receipient, _proof, _publicInputs);
    }

    function handle(uint32 _origin, bytes32 _sender, bytes memory _body) external onlyMailbox(){
        (uint256 instrType, uint256 nonceCount, uint256 packetNo, uint256 totalPackets, bytes memory data) = abi.decode(_body, (uint256, uint256, uint256, uint256, bytes));
        if(instrType == 1){
            contexts[abi.encode(_origin, _sender, nonceCount)] = ReceiverContext(bytes(""), 0, abi.decode(data, (address)));
        }else if(instrType == 2){
            require((keccak256(contexts[abi.encode(_origin, _sender, nonceCount)].data) == keccak256(bytes(""))) || (packetNo-1 == contexts[abi.encode(_origin, _sender, nonceCount)].lastReceivedPacket), "Message order is not matching !!!");
            contexts[abi.encode(_origin, _sender, nonceCount)].data = BytesLib.MergeBytes(contexts[abi.encode(_origin, _sender, nonceCount)].data, data);
            contexts[abi.encode(_origin, _sender, nonceCount)].lastReceivedPacket = packetNo;
            if(packetNo == totalPackets){
                bytes32 messageId = "";
                (bytes memory _proof, bytes32[] memory _publicInputs) = abi.decode(contexts[abi.encode(_origin, _sender, nonceCount)].data, (bytes, bytes32[]));
                try IVerifier(contexts[abi.encode(_origin, _sender, nonceCount)].recipient).verifyInputs(_proof, _publicInputs) returns(bool res){
                    messageId = IMailbox(mailbox).dispatch(_origin, _sender, abi.encode(3, nonceCount, 0, 0, abi.encode(keccak256(abi.encode(_proof, _publicInputs, contexts[abi.encode(_origin, _sender, nonceCount)].recipient)), res)));
                }catch{
                    messageId = IMailbox(mailbox).dispatch(_origin, _sender, abi.encode(3, nonceCount, 0, 0, abi.encode(keccak256(abi.encode(_proof, _publicInputs, contexts[abi.encode(_origin, _sender, nonceCount)].recipient)), false)));
                }
                // uint256 quote = IInterchainGasPaymaster(interchainGasPaymaster).quoteGasPayment(_origin, 1000000);
                // IInterchainGasPaymaster(interchainGasPaymaster).payForGas{value: quote}(
                //     messageId,
                //     _origin,
                //     1000000,
                //     address(this)
                // );
                //emit SentResult(_sender, contexts[abi.encode(_origin, _sender, nonceCount)].data);
            }
        }else if(instrType == 3){
            (bytes32 hashedKey, bool res) = abi.decode(data, (bytes32, bool));
            IReceiver(receiver[abi.encode(_origin, _sender, nonceCount)]).handleInterchainRes(res);
        }
    }


    function addressToBytes32(address _addr) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_addr)));
    }

    receive() payable external{}

    function destroy() external{
        selfdestruct(payable(msg.sender));
    }

}

library BytesLib {  
  function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        // Check length is 0. `iszero` return 1 for `true` and 0 for `false`.
        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // Calculate length mod 32 to handle slices that are not a multiple of 32 in size.
                let lengthmod := and(_length, 31)

                // tempBytes will have the following format in memory: <length><data>
                // When copying data we will offset the start forward to avoid allocating additional memory
                // Therefore part of the length area will be written, but this will be overwritten later anyways.
                // In case no offset is require, the start is set to the data region (0x20 from the tempBytes)
                // mc will be used to keep track where to copy the data to.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // Same logic as for mc is applied and additionally the start offset specified for the method is added
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    // increase `mc` and `cc` to read the next word from memory
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // Copy the data from source (cc location) to the slice data (mc location)
                    mstore(mc, mload(cc))
                }

                // Store the length of the slice. This will overwrite any partial data that 
                // was copied when having slices that are not a multiple of 32.
                mstore(tempBytes, _length)

                // update free-memory pointer
                // allocating the array padded to 32 bytes like the compiler does now
                // To set the used memory as a multiple of 32, add 31 to the actual memory usage (mc) 
                // and remove the modulo 32 (the `and` with `not(31)`)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // if we want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                // zero out the 32 bytes slice we are about to return
                // we need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                // update free-memory pointer
                // tempBytes uses 32 bytes in memory (even when empty) for the length.
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }

    function MergeBytes(bytes memory a, bytes memory b) public pure returns (bytes memory c) {
    // Store the length of the first array
    uint alen = a.length;
    // Store the length of BOTH arrays
    uint totallen = alen + b.length;
    // Count the loops required for array a (sets of 32 bytes)
    uint loopsa = (a.length + 31) / 32;
    // Count the loops required for array b (sets of 32 bytes)
    uint loopsb = (b.length + 31) / 32;
    assembly {
        let m := mload(0x40)
        // Load the length of both arrays to the head of the new bytes array
        mstore(m, totallen)
        // Add the contents of a to the array
        for {  let i := 0 } lt(i, loopsa) { i := add(1, i) } { mstore(add(m, mul(32, add(1, i))), mload(add(a, mul(32, add(1, i))))) }
        // Add the contents of b to the array
        for {  let i := 0 } lt(i, loopsb) { i := add(1, i) } { mstore(add(m, add(mul(32, add(1, i)), alen)), mload(add(b, mul(32, add(1, i))))) }
        mstore(0x40, add(m, add(32, totallen)))
        c := m
    }
    }
}
