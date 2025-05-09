// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteChainDGTv2 is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Events
    event ElectionCreated(uint round, string name);
    event CandidateAdded(uint round, uint8 id, string partyName);
    event PhaseChanged(uint round, uint8 newPhase);
    event VoterRegistered(uint round, address voter, uint32 stuId);
    event VoteCast(uint round, address voter, uint8 candidateId);

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
        uint256 voteCount;
    }

    struct Voter {
        bool registered;
        bool voted;
        bool token;
        uint32 stuId;
        string title;       // คำนำหน้า
        string firstName;   // ชื่อจริง
        string lastName;    // นามสกุล
        string branch;      // สาขา (DT, DC)
    }

    struct ElectionMeta {
        string name;
        uint8 phase; // 0-3
        uint8 candidateCount;
        uint32 registerCount;
        uint32 voteCount;
        uint16 adminCount;
    }

    // Storage variables
    uint public currentRound;
    mapping(uint => ElectionMeta) public meta;
    mapping(uint => mapping(uint8 => Candidate)) private candidates;
    mapping(uint => mapping(address => Voter)) private voters;
    mapping(uint => mapping(string => bool)) private partyNameUsed;

    // Mapping for storing admin addresses
    address[] public admins;

    // Struct to collect candidate data
    struct CandidateInfo {
        string title;
        string firstName;
        string lastName;
        string nickname;
        uint8 age;
        string branch;
        string partyName;
        string policy;
    }

    // Constructor
    constructor(address[] memory _admins) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // Set admins to the passed addresses
        for (uint i = 0; i < _admins.length; ++i) {
            _grantRole(ADMIN_ROLE, _admins[i]);
            admins.push(_admins[i]);  // Storing admin addresses
        }

        meta[0].adminCount = uint16(_admins.length);
    }

    /*======== Admin Functions ========*/
    
    // Get total number of admins
    function getAdminCount() external view returns (uint) {
        return admins.length; // Return the length of the admins array
    }

    // Get list of all admin addresses
    function getAdmins() external view returns (address[] memory) {
        return admins;  // Return the array of admin addresses
    }

    // Create a new election
    function createElection(string calldata name) external onlyRole(ADMIN_ROLE) {
        require(currentRound == 0 || meta[currentRound].phase == 3, "Prev round not closed");
        ++currentRound;

        meta[currentRound] = ElectionMeta({
            name: name,
            phase: 0, 
            candidateCount: 0,
            registerCount: 0,
            voteCount: 0,
            adminCount: meta[0].adminCount
        });

        emit ElectionCreated(currentRound, name);
    }

    // Add a candidate
    function addCandidate(CandidateInfo calldata candidateInfo) external onlyRole(ADMIN_ROLE) {
        ElectionMeta storage m = meta[currentRound];
        require(m.phase == 0, "Not in Setup");
        require(!partyNameUsed[currentRound][candidateInfo.partyName], "Party name used");

        uint8 id = m.candidateCount + 1;

        // ตรวจสอบว่า partyNumber ไม่ซ้ำกับผู้สมัครคนอื่นในรอบนี้
        require(candidates[currentRound][id].partyNumber != id, "Party number already taken");

        // Create candidate from CandidateInfo struct
        Candidate memory newCandidate = Candidate({
            id: id,
            title: candidateInfo.title,
            firstName: candidateInfo.firstName,
            lastName: candidateInfo.lastName,
            nickname: candidateInfo.nickname,
            age: candidateInfo.age,
            branch: candidateInfo.branch,
            partyNumber: id, // partyNumber ต้องตรงกับ id
            partyName: candidateInfo.partyName,
            policy: candidateInfo.policy,
            voteCount: 0
        });

        // Save the candidate to the mapping
        candidates[currentRound][id] = newCandidate;
        partyNameUsed[currentRound][candidateInfo.partyName] = true;
        m.candidateCount++;

        emit CandidateAdded(currentRound, id, candidateInfo.partyName);
    }

    // Change election phase (for admin only)
    function setPhase(uint8 newPhase) external onlyRole(ADMIN_ROLE) {
        ElectionMeta storage m = meta[currentRound];
        require(newPhase == m.phase + 1, "Phase must advance");
        m.phase = newPhase;
        emit PhaseChanged(currentRound, newPhase);
    }

    /*======== Voter Functions ========*/
    
    // Register a voter (Voter only)
    function registerVoter(
        address account,
        uint32 stuId,
        string calldata title,
        string calldata firstName,
        string calldata lastName,
        string calldata branch // DT, DC
    ) external {
        ElectionMeta storage m = meta[currentRound];
        require(m.phase == 1, "Registration closed");

        Voter storage v = voters[currentRound][account];
        require(!v.registered, "Already registered");

        // Store voter information
        v.registered = true;
        v.token = true;
        v.stuId = stuId;
        v.title = title;
        v.firstName = firstName;
        v.lastName = lastName;
        v.branch = branch;
        m.registerCount++;

        emit VoterRegistered(currentRound, account, stuId);
    }

    // Cast a vote (Voter only)
    function vote(
        address account,
        uint32 stuId,
        uint8 partyNumber
    ) external {
        ElectionMeta storage m = meta[currentRound];
        require(m.phase == 2, "Voting closed");

        // Verify the voter info matches the registration details
        Voter storage v = voters[currentRound][account];
        require(v.registered, "Not registered");
        require(v.stuId == stuId, "Student ID mismatch");
        require(!v.voted, "Already voted");
        require(v.token, "No voting token");

        // Ensure the candidate exists
        Candidate storage c = candidates[currentRound][partyNumber];
        require(c.id != 0, "Bad candidate");

        v.voted = true;
        v.token = false;
        c.voteCount++;
        m.voteCount++;

        emit VoteCast(currentRound, account, partyNumber);
    }

    /*======== Read-only Helpers ========*/
    
    // Get candidate info
    function getCandidate(uint round, uint8 id) external view returns (Candidate memory) {
        return candidates[round][id];
    }

    // Get election metadata
    function getElectionMeta(uint round) external view returns (ElectionMeta memory) {
        return meta[round];
    }

    // Get winner
    function getWinner(uint round)
        external
        view
        returns (uint8 winnerId, string memory partyName, uint256 votes)
    {
        require(meta[round].phase == 3, "Not closed");
        uint8 total = meta[round].candidateCount;

        for (uint8 i = 1; i <= total; ++i) {
            uint256 vc = candidates[round][i].voteCount;
            if (vc > votes) {
                votes = vc;
                winnerId = i;
                partyName = candidates[round][i].partyName;
            }
        }
    }
}
