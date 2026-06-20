// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IdentityRegistry} from "../src/IdentityRegistry.sol";
import {IIdentityRegistry} from "../src/interfaces/IIdentityRegistry.sol";

contract IdentityRegistryTest is Test {
    IdentityRegistry id;
    address alice = makeAddr("alice");

    uint256 constant AGENT = 42;

    function setUp() public {
        id = new IdentityRegistry();
    }

    function test_register_mintsAndEmitsAgentRegistered() public {
        vm.expectEmit(true, true, false, false, address(id));
        emit IIdentityRegistry.AgentRegistered(AGENT, alice);
        id.register(AGENT, alice);

        assertEq(id.ownerOf(AGENT), alice);
        assertEq(id.balanceOf(alice), 1);
        assertTrue(id.exists(AGENT));
    }

    function test_register_zeroOwner_reverts() public {
        vm.expectRevert(IdentityRegistry.ZeroAddress.selector);
        id.register(AGENT, address(0));
    }

    function test_register_twice_reverts() public {
        id.register(AGENT, alice);
        vm.expectRevert(abi.encodeWithSelector(IdentityRegistry.AlreadyRegistered.selector, AGENT));
        id.register(AGENT, alice);
    }

    function test_exists_falseForUnregistered() public view {
        assertFalse(id.exists(999));
    }

    function test_isErc721() public {
        id.register(AGENT, alice);
        assertEq(id.name(), "ANID Agent");
        assertEq(id.symbol(), "ANID");
        // ERC-721 interface id
        assertTrue(id.supportsInterface(0x80ac58cd));
    }
}
