// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

contract CommitLog {
    enum Decision {

        UNKNOWN,

        COMMIT,

        ABORT
    }

    struct TransactionRecord {
        string transactionId;
        Decision decision;
        uint256 timestamp;
        address coordinator;
        uint256 value;
    }

    mapping(string => TransactionRecord) public records;

    event DecisionRecorded(
        string transactionId, Decision decision, uint256 timestamp, address coordinator, uint256 value
    );

    function recordDecision(string memory transactionId, Decision decision, uint256 value) public {
        require(records[transactionId].decision == Decision.UNKNOWN, "Decision already recorded");
        require(decision == Decision.COMMIT || decision == Decision.ABORT, "Invalid decision");

        records[transactionId] = TransactionRecord({
            transactionId: transactionId,
            decision: decision,
            timestamp: block.timestamp,
            coordinator: msg.sender,
            value: value
        });

        emit DecisionRecorded(transactionId, decision, block.timestamp, msg.sender, value);
    }

    function getDecision(string memory transactionId)
        public
        view
        returns (Decision decision, uint256 timestamp, address coordinator, uint256 value)
    {
        TransactionRecord storage record = records[transactionId];
        return (record.decision, record.timestamp, record.coordinator, record.value);
    }
}
