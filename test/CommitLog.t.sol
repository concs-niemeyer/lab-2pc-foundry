// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/CommitLog.sol";

contract CommitLogTest is Test {
    CommitLog public commitLog;
    address public coordinator = address(0x123);

    function setUp() public {
        commitLog = new CommitLog();
    }

    function testRecordDecision() public {
        string memory txId = "tx-123";
        uint256 amount = 100;

        vm.prank(coordinator);
        commitLog.recordDecision(txId, CommitLog.Decision.COMMIT, amount);

        (CommitLog.Decision decision, uint256 timestamp, address recordedCoordinator, uint256 recordedAmount) =
            commitLog.getDecision(txId);

        assertEq(uint8(decision), uint8(CommitLog.Decision.COMMIT));
        assertEq(timestamp, block.timestamp);
        assertEq(recordedCoordinator, coordinator);
        assertEq(recordedAmount, amount);
    }

    function testRecordAbort() public {
        string memory txId = "tx-456";
        uint256 amount = 200;

        vm.prank(coordinator);
        commitLog.recordDecision(txId, CommitLog.Decision.ABORT, amount);

        (CommitLog.Decision decision,,, uint256 recordedAmount) = commitLog.getDecision(txId);

        assertEq(uint8(decision), uint8(CommitLog.Decision.ABORT));
        assertEq(recordedAmount, amount);
    }

    function testCannotRecordTwice() public {
        string memory txId = "tx-789";

        commitLog.recordDecision(txId, CommitLog.Decision.COMMIT, 100);

        vm.expectRevert("Decision already recorded");
        commitLog.recordDecision(txId, CommitLog.Decision.ABORT, 200);
    }

    function testCannotRecordInvalidDecision() public {
        string memory txId = "tx-000";

        vm.expectRevert("Invalid decision");
        commitLog.recordDecision(txId, CommitLog.Decision.UNKNOWN, 100);
    }
}
