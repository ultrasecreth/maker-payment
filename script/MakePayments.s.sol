// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Script} from "forge-std/Script.sol";
import {StdAssertions} from "forge-std/StdAssertions.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISafe} from "../src/dependencies/ISafe.sol";
import {Enum} from "../src/dependencies/Enum.sol";

contract MakePayments is Script, StdAssertions {
    ISafe launch = ISafe(0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F);
    ISafe integration = ISafe(0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7);

    ISafe ecoInspector = ISafe(0x88B3e82A55c5215d0499Da4bBd63fc3e43F26232);
    address retro = 0xa648640060d5d00914c05C10bDe3e0CBa5c88CD2;

    ISafe accounting = ISafe(0xA2A855Ac8D2a92e8A5a437690875261535c8320C);
    address ketcher = 0xFC614b8570662B9A824BD4148e4d21B9D3fa5589;

    IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    IERC20 sky = IERC20(0x56072C95FAA701256059aa122697B133aDEd9279);

    address recipient = makeAddr("recipient");

    function run() public {
        uint256 nonce = launch.nonce();
        bytes32 dataHash = launch.getTransactionHash({
            to: address(usds),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, recipient, 100e18),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            _nonce: nonce
        });

        // vm.prank(address(ecoInspector));
        // launch.approveHash(dataHash);

        vm.prank(address(accounting));
        launch.approveHash(dataHash);

        bytes memory launchCall = abi.encodeCall(
            ISafe.execTransaction,
            (
                address(usds),
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, recipient, 100e18),
                Enum.Operation.Call,
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

        assertEqDecimal(usds.balanceOf(recipient), 100e18, 18);
    }
}
