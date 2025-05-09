// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract VoteChainSimple {
    // Events
    event CandidateAdded(uint8 id, string partyName);
    event CandidateRemoved(uint8 id, string partyName);

    // Structs
    struct Candidate {
        uint8 id;
        string title;
        string firstName;
        string lastName;
        string nickname;
        uint8 age;
        string branch;
        uint8 partyNumber;
        string partyName;
        string policy;
        uint256 addedTimestamp;
    }

    // Storage
    address public admin;
    mapping(uint8 => Candidate) public candidates;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    // เพิ่มผู้สมัคร
    function addCandidate(
        uint8 id,
        string calldata title,
        string calldata firstName,
        string calldata lastName,
        string calldata nickname,
        uint8 age,
        string calldata branch,
        uint8 partyNumber,
        string calldata partyName,
        string calldata policy
    ) external onlyAdmin {
        require(candidates[id].id == 0, "Candidate ID already exists");

        candidates[id] = Candidate({
            id: id,
            title: title,
            firstName: firstName,
            lastName: lastName,
            nickname: nickname,
            age: age,
            branch: branch,
            partyNumber: partyNumber,
            partyName: partyName,
            policy: policy,
            addedTimestamp: block.timestamp
        });

        emit CandidateAdded(id, partyName);
    }

    // ลบผู้สมัคร
    function removeCandidate(uint8 id) external onlyAdmin {
        require(candidates[id].id != 0, "Candidate not found");

        string memory partyName = candidates[id].partyName;
        delete candidates[id];

        emit CandidateRemoved(id, partyName);
    }

    // ดึงข้อมูลผู้สมัคร
    function getCandidateByPartyNumber(uint8 id) external view returns (Candidate memory) {
        require(candidates[id].id != 0, "Candidate not found");
        return candidates[id];
    }
}
