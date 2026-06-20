// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {EngineRegistry} from "../src/EngineRegistry.sol";
import {IEngineRegistry} from "../src/interfaces/IEngineRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract EngineRegistryTest is Test {
    EngineRegistry reg;
    address owner = address(this);
    address engine = makeAddr("engine");
    address notOwner = makeAddr("notOwner");

    function setUp() public {
        reg = new EngineRegistry(owner);
    }

    function test_register_setsMembershipAndEmits() public {
        vm.expectEmit(true, false, false, false, address(reg));
        emit IEngineRegistry.EngineRegistered(engine);
        reg.register(engine);
        assertTrue(reg.isRegistered(engine));
    }

    function test_deregister_clearsMembershipAndEmits() public {
        reg.register(engine);
        vm.expectEmit(true, false, false, false, address(reg));
        emit IEngineRegistry.EngineDeregistered(engine);
        reg.deregister(engine);
        assertFalse(reg.isRegistered(engine));
    }

    function test_register_onlyOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        reg.register(engine);
    }

    function test_deregister_onlyOwner() public {
        reg.register(engine);
        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        reg.deregister(engine);
    }

    function test_register_zeroAddress_reverts() public {
        vm.expectRevert(EngineRegistry.ZeroAddress.selector);
        reg.register(address(0));
    }

    function test_register_twice_reverts() public {
        reg.register(engine);
        vm.expectRevert(abi.encodeWithSelector(EngineRegistry.AlreadyRegistered.selector, engine));
        reg.register(engine);
    }

    function test_deregister_unknown_reverts() public {
        vm.expectRevert(abi.encodeWithSelector(EngineRegistry.NotRegistered.selector, engine));
        reg.deregister(engine);
    }
}
