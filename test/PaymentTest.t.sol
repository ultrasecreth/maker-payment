// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ISafe} from "../src/dependencies/ISafe.sol";
import {Enum} from "../src/dependencies/Enum.sol";

contract PaymentTest is Test {
    ISafe launch = ISafe(0x3C5142F28567E6a0F172fd0BaaF1f2847f49D02F);
    ISafe integration = ISafe(0xD6891d1DFFDA6B0B1aF3524018a1eE2E608785F7);

    ISafe ecoInspector = ISafe(0x88B3e82A55c5215d0499Da4bBd63fc3e43F26232);
    address retro = 0xa648640060d5d00914c05C10bDe3e0CBa5c88CD2;

    ISafe accounting = ISafe(0xA2A855Ac8D2a92e8A5a437690875261535c8320C);
    address ketcher = 0xFC614b8570662B9A824BD4148e4d21B9D3fa5589;

    IERC20 usds = IERC20(0xdC035D45d973E3EC169d2276DDab16f1e407384F);
    IERC20 sky = IERC20(0x56072C95FAA701256059aa122697B133aDEd9279);

    address recipient = makeAddr("recipient");

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_URL"));
    }

    function test_makePayment() public {
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

        console.logBytes32(keccak256(encodeMessageDataForSafe(launch, abi.encode(dataHash))));

        vm.prank(address(retro));
        ecoInspector.approveHash(dataHash);

        vm.prank(address(ketcher));
        accounting.approveHash(dataHash);

        // vm.prank(address(ecoInspector));

        bytes memory signatures = abi.encodePacked(
            bytes32(uint256(uint160(address(ecoInspector)))),
            bytes32(uint256(65 * 2)),
            uint8(0),
            bytes32(uint256(uint160(address(accounting)))),
            bytes32(uint256(65 * 2)),
            uint8(0),
            bytes32(0)
        );

        launch.execTransaction({
            to: address(usds),
            value: 0,
            data: abi.encodeWithSelector(IERC20.transfer.selector, recipient, 100e18),
            operation: Enum.Operation.Call,
            safeTxGas: 0,
            baseGas: 0,
            gasPrice: 0,
            gasToken: address(0),
            refundReceiver: payable(address(0)),
            signatures: signatures
        });

        assertEqDecimal(usds.balanceOf(recipient), 100e18, 18);
    }

    // keccak256("SafeMessage(bytes message)");
    bytes32 private constant SAFE_MSG_TYPEHASH = 0x60b3cbf8b4a223d68d641b3b6ddf9a298e7f33710cf3d3a9d1146b5a6150fbca;

    function encodeMessageDataForSafe(ISafe safe, bytes memory message) public view returns (bytes memory) {
        bytes32 safeMessageHash = keccak256(abi.encode(SAFE_MSG_TYPEHASH, keccak256(message)));
        return abi.encodePacked(bytes1(0x19), bytes1(0x01), safe.domainSeparator(), safeMessageHash);
    }
}
