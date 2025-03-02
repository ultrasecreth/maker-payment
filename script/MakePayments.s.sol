// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Script} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISafe} from "../src/dependencies/ISafe.sol";
import {Enum} from "../src/dependencies/Enum.sol";
import {IMultiSend} from "../src/dependencies/IMultiSend.sol";

contract MakePayments is Script, StdAssertions {
    ISafe launch = ISafe(0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F);
    ISafe integration = ISafe(0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7);

    ISafe ecoInspector = ISafe(0x88B3e82A55c5215d0499Da4bBd63fc3e43F26232);
    address retro = 0xa648640060d5d00914c05C10bDe3e0CBa5c88CD2;

    ISafe accounting = ISafe(0xA2A855Ac8D2a92e8A5a437690875261535c8320C);
    address ketcher = 0xFC614b8570662B9A824BD4148e4d21B9D3fa5589;

    IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    IERC20 sky = IERC20(0x56072C95FAA701256059aa122697B133aDEd9279);

    struct Payment {
        address token;
        address recipient;
        uint256 amount;
    }

    Payment[] payments;

    function run() public {
        (address to, bytes memory data) = encodeMultiSend();

        uint256 nonce = launch.nonce();
        bytes32 dataHash = launch.getTransactionHash({
            to: to,
            value: 0,
            data: data,
            operation: Enum.Operation.DelegateCall,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            _nonce: nonce
        });

        console.log("Please approve this dataHash");
        console.logBytes32(dataHash);

        // Comment out when running for real
        vm.prank(address(accounting));
        launch.approveHash(dataHash);

        bytes memory launchCall = abi.encodeCall(
            ISafe.execTransaction,
            (
                to,
                0,
                data,
                Enum.Operation.DelegateCall,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                abi.encodePacked(
                    bytes32(uint256(uint160(address(ecoInspector)))),
                    bytes32(""),
                    uint8(1),
                    bytes32(uint256(uint160(address(accounting)))),
                    bytes32(""),
                    uint8(1)
                )
            )
        );

        vm.prank(address(retro));
        // vm.broadcast();
        ecoInspector.execTransaction({
            to: address(launch),
            value: 0,
            data: launchCall,
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: abi.encodePacked(bytes32(uint256(uint160(address(retro)))), bytes32(""), uint8(1))
        });

        for (uint256 i = 0; i < payments.length; i++) {
            assertGe(IERC20(payments[i].token).balanceOf(payments[i].recipient), payments[i].amount);
        }
    }

    function _readCSV(string memory path) internal {
        string memory line = vm.readLine(path);
        while (bytes(line).length > 0) {
            string[] memory values = vm.split(line, ",");
            payments.push(
                Payment({
                    token: vm.parseAddress(values[1]),
                    recipient: vm.parseAddress(values[2]),
                    amount: vm.parseUint(string.concat(values[3], " ether"))
                })
            );
            line = vm.readLine(path);
        }
        vm.closeFile(path);
    }

    function encodeMultiSend() internal returns (address to, bytes memory data) {
        _readCSV("payments.csv");

        for (uint256 i = 0; i < payments.length; i++) {
            bytes memory call = abi.encodeCall(IERC20.transfer, (payments[i].recipient, payments[i].amount));

            data =
                abi.encodePacked(data, Enum.Operation.Call, address(payments[i].token), uint256(0), call.length, call);
        }
        return (0xA238CBeb142c10Ef7Ad8442C6D1f9E89e07e7761, abi.encodeCall(IMultiSend.multiSend, (data)));
    }
}
