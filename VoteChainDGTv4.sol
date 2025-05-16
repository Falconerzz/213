// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteChainDGTv2 is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Events
    event CandidateAdded(uint8 candidateId, string partyName);
    event VoterRegistered(address voterAccount, string studentId);
    event VoteCast(address voterAccount, uint8 candidateId);
    event VotingPeriodSet(uint256 startTimestamp, uint256 endTimestamp);

    // Structs
    struct Candidate {
        uint8 candidateId;
        string candidateTitle;
        string candidateFirstName;
        string candidateLastName;
        string candidateNickname;
        uint8 candidateAge;
        string candidateBranch;
        string candidateStudentId;
        uint8 candidatePartyNumber;
        string candidatePartyName;
        string candidatePolicy;
        uint256 totalVotes;
        uint256 timeAdded;
    }

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        bool hasVotingToken;
        string studentId;
        string voterTitle;
        string voterFirstName;
        string voterLastName;
        string voterBranch;
    }

    struct PartyVoteResult {
        uint8 partyNumber;
        uint256 voteCount;
    }

    uint8 public totalCandidates = 0;
    uint32 public totalRegisteredVoters = 0;
    uint32 public totalVotesCast = 0;
    uint16 public totalAdmins = 0;

    mapping(uint8 => Candidate) private candidates;
    mapping(address => Voter) private voters;
    mapping(string => bool) private partyNameUsed;
    mapping(string => bool) private studentIdsUsed;
    mapping(string => bool) private candidateStudentIdsUsed;

    address[] public adminAddresses;

    uint256 public votingStartTime;
    uint256 public votingEndTime;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        adminAddresses.push(msg.sender);
        totalAdmins = 1;
    }

    function setVotingPeriod(uint256 startTimestamp, uint256 endTimestamp) external onlyRole(ADMIN_ROLE) {
        require(startTimestamp < endTimestamp, "Start must be before end");
        votingStartTime = startTimestamp;
        votingEndTime = endTimestamp;

        emit VotingPeriodSet(startTimestamp, endTimestamp);
    }

    function isValidStudentId(string memory studentId) internal pure returns (bool) {
        if (bytes(studentId).length != 8) {
            return false;
        }

        bytes1 level = bytes(studentId)[0];
        if (level != "B" && level != "M" && level != "D") {
            return false;
        }

        uint256 checksum = (uint256(uint8(bytes(studentId)[1])) - 48) *
            49 +
            (uint256(uint8(bytes(studentId)[2])) - 48) *
            7 +
            (uint256(uint8(bytes(studentId)[3])) - 48) *
            49 +
            (uint256(uint8(bytes(studentId)[4])) - 48) *
            7 +
            (uint256(uint8(bytes(studentId)[5])) - 48) *
            49 +
            (uint256(uint8(bytes(studentId)[6])) - 48) *
            7;
        checksum = checksum % 10;

        uint256 lastDigit = uint256(uint8(bytes(studentId)[7])) - 48;
        return checksum == lastDigit;
    }

    function addCandidate(
        uint8 candidateId,
        string calldata candidateTitle,
        string calldata candidateFirstName,
        string calldata candidateLastName,
        string calldata candidateNickname,
        uint8 candidateAge,
        string calldata candidateBranch,
        string calldata candidateStudentId,
        uint8 candidatePartyNumber,
        string calldata candidatePartyName,
        string calldata candidatePolicy
    ) external onlyRole(ADMIN_ROLE) {
        require(
            block.timestamp < votingStartTime || votingStartTime == 0,
            "Cannot add candidates during voting period"
        );
        require(isValidStudentId(candidateStudentId), "Invalid candidate student ID format");
        require(!partyNameUsed[candidatePartyName], "Party name already used");
        require(candidateId > 0 && candidateId <= 255, "ID must be between 1 and 255");
        require(candidatePartyNumber > 0 && candidatePartyNumber <= 255, "Party number must be between 1 and 255");
        require(candidates[candidateId].candidateId == 0, "ID already taken");
        require(candidates[candidatePartyNumber].candidatePartyNumber == 0, "Party number already taken");
        require(!candidateStudentIdsUsed[candidateStudentId], "Candidate Student ID already used");

        Candidate memory newCandidate = Candidate({
            candidateId: candidateId,
            candidateTitle: candidateTitle,
            candidateFirstName: candidateFirstName,
            candidateLastName: candidateLastName,
            candidateNickname: candidateNickname,
            candidateAge: candidateAge,
            candidateBranch: candidateBranch,
            candidateStudentId: candidateStudentId,
            candidatePartyNumber: candidatePartyNumber,
            candidatePartyName: candidatePartyName,
            candidatePolicy: candidatePolicy,
            totalVotes: 0,
            timeAdded: block.timestamp
        });

        candidates[candidateId] = newCandidate;
        partyNameUsed[candidatePartyName] = true;
        candidateStudentIdsUsed[candidateStudentId] = true;

        if (candidateId > totalCandidates) {
            totalCandidates = candidateId;
        }

        emit CandidateAdded(candidateId, candidatePartyName);
    }

    function registerVoter(
        address voterAccount,
        string calldata studentId,
        string calldata voterTitle,
        string calldata voterFirstName,
        string calldata voterLastName,
        string calldata voterBranch
    ) external {
        require(block.timestamp >= votingStartTime && block.timestamp <= votingEndTime, "Registration is only allowed during voting period");
        require(!hasRole(ADMIN_ROLE, msg.sender), "Admins cannot register as voters");

        require(isValidStudentId(studentId), "Invalid student ID format");
        require(!studentIdsUsed[studentId], "Student ID already registered");
        require(!candidateStudentIdsUsed[studentId], "Candidate Student ID cannot register as voter");

        Voter storage voterData = voters[voterAccount];
        require(!voterData.isRegistered, "Already registered");

        voterData.isRegistered = true;
        voterData.hasVotingToken = true;
        voterData.studentId = studentId;
        voterData.voterTitle = voterTitle;
        voterData.voterFirstName = voterFirstName;
        voterData.voterLastName = voterLastName;
        voterData.voterBranch = voterBranch;
        totalRegisteredVoters++;

        studentIdsUsed[studentId] = true;

        emit VoterRegistered(voterAccount, studentId);
    }

    function vote(
        address voterAccount,
        string calldata studentId,
        uint8 candidatePartyNumber
    ) external {
        require(block.timestamp >= votingStartTime && block.timestamp <= votingEndTime, "Voting is closed");

        Voter storage voterData = voters[voterAccount];
        require(voterData.isRegistered, "Not registered");
        require(keccak256(abi.encodePacked(voterData.studentId)) == keccak256(abi.encodePacked(studentId)), "Student ID mismatch");
        require(!voterData.hasVoted, "Already voted");
        require(voterData.hasVotingToken, "No voting token");

        Candidate storage candidateData = candidates[candidatePartyNumber];
        require(candidateData.candidateId != 0, "Bad candidate");

        voterData.hasVoted = true;
        voterData.hasVotingToken = false;
        candidateData.totalVotes++;
        totalVotesCast++;

        emit VoteCast(voterAccount, candidatePartyNumber);
    }

    /*======== Read-only Helpers ========*/

    function getAllCandidates() external view returns (uint8, Candidate[] memory) {
        Candidate[] memory candidateList = new Candidate[](totalCandidates);
        uint8 index = 0;

        for (uint8 i = 1; i <= totalCandidates; i++) {
            if (candidates[i].candidateId != 0) {
                candidateList[index] = candidates[i];
                index++;
            }
        }
        return (totalCandidates, candidateList);
    }

    function getCandidateByPartyNumber(uint8 partyNumber)
        external
        view
        returns (
            uint8 candidateId,
            string memory candidateTitle,
            string memory candidateFirstName,
            string memory candidateLastName,
            string memory candidateNickname,
            uint8 candidateAge,
            string memory candidateBranch,
            string memory candidateStudentId,
            uint8 candidatePartyNumber,
            string memory candidatePartyName,
            string memory candidatePolicy,
            uint256 timeAdded
        )
    {
        Candidate storage candidate = candidates[partyNumber];
        require(candidate.candidateId != 0, "Candidate not found");

        return (
            candidate.candidateId,
            candidate.candidateTitle,
            candidate.candidateFirstName,
            candidate.candidateLastName,
            candidate.candidateNickname,
            candidate.candidateAge,
            candidate.candidateBranch,
            candidate.candidateStudentId,
            candidate.candidatePartyNumber,
            candidate.candidatePartyName,
            candidate.candidatePolicy,
            candidate.timeAdded
        );
    }

    function getAllPartyVotes() external view returns (PartyVoteResult[] memory partyVoteResults) {
        require(block.timestamp > votingEndTime, "Election not ended yet");
        PartyVoteResult[] memory voteList = new PartyVoteResult[](totalCandidates);
        uint8 index = 0;

        for (uint8 i = 1; i <= totalCandidates; i++) {
            if (candidates[i].candidateId != 0) {
                voteList[index] = PartyVoteResult({
                    partyNumber: candidates[i].candidatePartyNumber,
                    voteCount: candidates[i].totalVotes
                });
                index++;
            }
        }

        return voteList;
    }

    function getWinningParty() external view returns (uint8 winningPartyNumber, string memory winningPartyName, uint256 highestVotes) {
        require(block.timestamp > votingEndTime, "Election not ended yet");

        uint8 winningPartyNumberTemp = 0;
        string memory winningPartyNameTemp = "";
        uint256 highestVotesTemp = 0;

        for (uint8 i = 1; i <= totalCandidates; i++) {
            if (candidates[i].candidateId != 0) {
                uint256 currentVotes = candidates[i].totalVotes;
                if (currentVotes > highestVotesTemp) {
                    highestVotesTemp = currentVotes;
                    winningPartyNumberTemp = candidates[i].candidatePartyNumber;
                    winningPartyNameTemp = candidates[i].candidatePartyName;
                }
            }
        }

        require(winningPartyNumberTemp != 0, "No candidates found");
        return (winningPartyNumberTemp, winningPartyNameTemp, highestVotesTemp);
    }

    // แก้ไขฟังก์ชัน getWinner ตามที่ขอ
    function getWinner() external view returns (uint8 partyNumber, string memory partyName, string memory candidatePolicy, uint256 votes) {
        require(block.timestamp > votingEndTime, "Election not ended yet");

        uint256 maxVotes = 0;
        uint8 winnerId = 0;

        for (uint8 i = 1; i <= totalCandidates; ++i) {
            uint256 vc = candidates[i].totalVotes;
            if (vc > maxVotes) {
                maxVotes = vc;
                winnerId = i;
            }
        }

        require(winnerId != 0, "No winner found");

        partyNumber = candidates[winnerId].candidatePartyNumber;
        partyName = candidates[winnerId].candidatePartyName;
        candidatePolicy = candidates[winnerId].candidatePolicy;
        votes = candidates[winnerId].totalVotes;
    }

    function getAdmins() external view returns (address[] memory) {
        return adminAddresses;
    }
}
