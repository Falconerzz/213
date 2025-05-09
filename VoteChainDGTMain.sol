// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteChainDGTv2 is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Events
    event CandidateAdded(uint8 id, string partyName);
    event CandidateRemoved(uint8 partyNumber, string partyName);
    event VoterRegistered(address voter, string stuId);
    event VoteCast(address voter, uint8 candidateId);
    event ElectionPeriodSet(uint256 startTime, uint256 endTime);

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
        uint256 addedTimestamp;
    }

    struct Voter {
        bool registered;
        bool voted;
        bool token;
        string stuId;
        string title;
        string firstName;
        string lastName;
        string branch;
    }

    struct ElectionMeta {
        string name;
        uint256 startTime;
        uint256 endTime;
        uint8 candidateCount;
        uint32 registerCount;
        uint32 voteCount;
        uint16 adminCount;
    }

    // Struct to collect candidate input data
    struct CandidateInput {
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
    }

    // Struct for returning party vote results
    struct PartyVote {
        uint8 partyNumber;
        uint256 voteCount;
    }

    // Storage variables
    ElectionMeta public meta;
    mapping(uint8 => Candidate) private candidates;
    mapping(address => Voter) private voters;
    mapping(string => bool) private partyNameUsed;
    mapping(string => bool) private studentIdsUsed;

    // Mapping for storing admin addresses
    address[] public admins;

    // Constructor
    constructor(address[] memory _admins) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        for (uint i = 0; i < _admins.length; ++i) {
            _grantRole(ADMIN_ROLE, _admins[i]);
            admins.push(_admins[i]);
        }

        meta = ElectionMeta({
            name: "",
            startTime: 0,
            endTime: 0,
            candidateCount: 0,
            registerCount: 0,
            voteCount: 0,
            adminCount: uint16(_admins.length)
        });
    }

    // ฟังก์ชันตรวจสอบรหัสนักศึกษา SUT
    function isValidID(string memory studentID) internal pure returns (bool) {
        if (bytes(studentID).length != 8) {
            return false;
        }

        bytes1 level = bytes(studentID)[0];
        if (level != 'B' && level != 'M' && level != 'D') {
            return false;
        }

        uint checksum = (uint(uint8(bytes(studentID)[1])) - 48) * 49 +
                        (uint(uint8(bytes(studentID)[2])) - 48) * 7 +
                        (uint(uint8(bytes(studentID)[3])) - 48) * 49 +
                        (uint(uint8(bytes(studentID)[4])) - 48) * 7 +
                        (uint(uint8(bytes(studentID)[5])) - 48) * 49 +
                        (uint(uint8(bytes(studentID)[6])) - 48) * 7;
        checksum = checksum % 10;

        uint lastDigit = uint(uint8(bytes(studentID)[7])) - 48;
        return checksum == lastDigit;
    }

    /*======== Admin Functions ========*/
    
    // Get total number of admins
    function getAdminCount() external view onlyRole(ADMIN_ROLE) returns (uint) {
        return admins.length;
    }

    // Get list of all admin addresses
    function getAdmins() external view onlyRole(ADMIN_ROLE) returns (address[] memory) {
        return admins;
    }

    // Set election period (start and end time)
    function setElectionPeriod(uint256 _startTime, uint256 _endTime) external onlyRole(ADMIN_ROLE) {
        require(_startTime < _endTime, "Start time must be before end time");
        require(_startTime > block.timestamp, "Start time must be in the future");

        meta.startTime = _startTime;
        meta.endTime = _endTime;

        emit ElectionPeriodSet(_startTime, _endTime);
    }

    // Add a candidate using CandidateInput struct
    function addCandidate(CandidateInput calldata input) external onlyRole(ADMIN_ROLE) {
        require(block.timestamp < meta.startTime || meta.startTime == 0, "Cannot add candidate after election starts");
        require(!partyNameUsed[input.partyName], "Party name already used");
        require(input.id > 0 && input.id <= 255, "ID must be between 1 and 255");
        require(input.partyNumber > 0 && input.partyNumber <= 255, "Party number must be between 1 and 255");
        require(candidates[input.id].id == 0, "ID already taken");
        require(candidates[input.partyNumber].partyNumber == 0 || candidates[input.partyNumber].partyNumber == input.partyNumber, "Party number already taken");

        Candidate memory newCandidate = Candidate({
            id: input.id,
            title: input.title,
            firstName: input.firstName,
            lastName: input.lastName,
            nickname: input.nickname,
            age: input.age,
            branch: input.branch,
            partyNumber: input.partyNumber,
            partyName: input.partyName,
            policy: input.policy,
            voteCount: 0,
            addedTimestamp: block.timestamp
        });

        candidates[input.id] = newCandidate;
        partyNameUsed[input.partyName] = true;
        if (input.id > meta.candidateCount) {
            meta.candidateCount = input.id;
        }

        emit CandidateAdded(input.id, input.partyName);
    }

    // Remove a candidate by party number
    function removeCandidate(uint8 partyNumber) external onlyRole(ADMIN_ROLE) {
        require(block.timestamp < meta.startTime || meta.startTime == 0, "Cannot remove candidate after election starts");
        require(candidates[partyNumber].id != 0, "Candidate not found");

        string memory partyName = candidates[partyNumber].partyName;
        delete candidates[partyNumber];
        delete partyNameUsed[partyName];

        // Recalculate candidateCount
        uint8 maxId = 0;
        for (uint8 i = 1; i <= meta.candidateCount; i++) {
            if (candidates[i].id != 0 && i > maxId) {
                maxId = i;
            }
        }
        meta.candidateCount = maxId;

        emit CandidateRemoved(partyNumber, partyName);
    }

    // Get election metadata
    function getElectionMeta() external view onlyRole(ADMIN_ROLE) returns (ElectionMeta memory) {
        return meta;
    }

    /*======== Voter Functions ========*/
    
    // Register a voter (Voter only)
    function registerVoter(
        address account,
        string calldata stuId,
        string calldata title,
        string calldata firstName,
        string calldata lastName,
        string calldata branch
    ) external {
        require(block.timestamp >= meta.startTime && block.timestamp <= meta.endTime, "Not within election period");

        require(isValidID(stuId), "Invalid student ID format");
        require(!studentIdsUsed[stuId], "Student ID already registered");

        Voter storage v = voters[account];
        require(!v.registered, "Already registered");

        v.registered = true;
        v.token = true;
        v.stuId = stuId;
        v.title = title;
        v.firstName = firstName;
        v.lastName = lastName;
        v.branch = branch;
        meta.registerCount++;

        studentIdsUsed[stuId] = true;
        emit VoterRegistered(account, stuId);
    }

    // Cast a vote (Voter only)
    function vote(
        address account,
        string calldata stuId,
        uint8 partyNumber
    ) external {
        require(block.timestamp >= meta.startTime && block.timestamp <= meta.endTime, "Not within election period");

        Voter storage v = voters[account];
        require(v.registered, "Not registered");
        require(keccak256(abi.encodePacked(v.stuId)) == keccak256(abi.encodePacked(stuId)), "Student ID mismatch");
        require(!v.voted, "Already voted");
        require(v.token, "No voting token");

        Candidate storage c = candidates[partyNumber];
        require(c.id != 0, "Bad candidate");

        v.voted = true;
        v.token = false;
        c.voteCount++;
        meta.voteCount++;

        emit VoteCast(account, partyNumber);
    }

    /*======== Shared Functions (Admin and Voter) ========*/
    
    // Get all candidates with total count
    function getAllCandidates() external view returns (uint8 totalCandidates, Candidate[] memory allCandidates) {
        uint8 candidateCount = meta.candidateCount;
        Candidate[] memory candidateList = new Candidate[](candidateCount);
        uint8 index = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[i].id != 0) {
                candidateList[index] = candidates[i];
                index++;
            }
        }

        return (candidateCount, candidateList);
    }

    // Get candidate details by party number (excluding vote count)
    function getCandidateByPartyNumber(uint8 partyNumber) external view returns (
        uint8 id,
        string memory title,
        string memory firstName,
        string memory lastName,
        string memory nickname,
        uint8 age,
        string memory branch,
        uint8 partyNum,
        string memory partyName,
        string memory policy,
        uint256 addedTimestamp
    ) {
        Candidate storage candidate = candidates[partyNumber];
        require(candidate.id != 0, "Candidate not found");

        return (
            candidate.id,
            candidate.title,
            candidate.firstName,
            candidate.lastName,
            candidate.nickname,
            candidate.age,
            candidate.branch,
            candidate.partyNumber,
            candidate.partyName,
            candidate.policy,
            candidate.addedTimestamp
        );
    }

    // Get vote counts for all parties (only after election ends)
    function getAllPartyVotes() external view returns (PartyVote[] memory partyVotes) {
        require(block.timestamp > meta.endTime, "Election not closed");
        uint8 candidateCount = meta.candidateCount;
        PartyVote[] memory voteList = new PartyVote[](candidateCount);
        uint8 index = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[i].id != 0) {
                voteList[index] = PartyVote({
                    partyNumber: candidates[i].partyNumber,
                    voteCount: candidates[i].voteCount
                });
                index++;
            }
        }

        return voteList;
    }

    // Get the winning candidate details (only after election ends)
    function getWinningParty() external view returns (Candidate memory) {
        require(block.timestamp > meta.endTime, "Election not closed");
        uint8 candidateCount = meta.candidateCount;
        Candidate memory winningCandidate;
        uint256 highestVotes = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[i].id != 0) {
                uint256 currentVotes = candidates[i].voteCount;
                if (currentVotes > highestVotes) {
                    highestVotes = currentVotes;
                    winningCandidate = candidates[i];
                }
            }
        }

        require(winningCandidate.id != 0, "No candidates found");
        return winningCandidate;
    }
}
