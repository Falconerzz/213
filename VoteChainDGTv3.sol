// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract VoteChainDGTv2 is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // Events
    event ElectionCreated(uint256 electionRound, string electionName);
    event CandidateAdded(uint256 electionRound, uint8 candidateId, string partyName);
    event ElectionPhaseChanged(uint256 electionRound, uint8 newElectionPhase);
    event VoterRegistered(uint256 electionRound, address voterAccount, string studentId);
    event VoteCast(uint256 electionRound, address voterAccount, uint8 candidateId);

    // Structs
    struct Candidate {
        uint8 candidateId;
        string candidateTitle;
        string candidateFirstName;
        string candidateLastName;
        string candidateNickname;
        uint8 candidateAge;
        string candidateBranch;
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

    struct ElectionMeta {
        string electionName;
        uint8 electionPhase;  // 0-3 (Setup, Registration, Voting, Closed)
        uint8 totalCandidates;
        uint32 totalRegisteredVoters;
        uint32 totalVotesCast;
        uint16 totalAdmins;
    }

    // Struct for returning party vote results
    struct PartyVoteResult {
        uint8 partyNumber;
        uint256 voteCount;
    }

    // Storage variables
    uint256 public currentRound = 1;
    mapping(uint256 => ElectionMeta) public electionMeta;
    mapping(uint256 => mapping(uint8 => Candidate)) private candidates;
    mapping(uint256 => mapping(address => Voter)) private voters;
    mapping(uint256 => mapping(string => bool)) private partyNameUsed; // Check if party name is used
    mapping(uint256 => mapping(string => bool)) private studentIdsUsed; // Check if student ID is used

    // Mapping for storing admin addresses
    address[] public adminAddresses;

    // Constructor
    constructor(address[] memory _admins) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        for (uint256 i = 0; i < _admins.length; ++i) {
            _grantRole(ADMIN_ROLE, _admins[i]);
            adminAddresses.push(_admins[i]);
        }

        electionMeta[1].totalAdmins = uint16(_admins.length);
    }

    // Function to validate student ID
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

    /*======== Admin Functions ========*/

    function getAdminCount() external view returns (uint256) {
        return adminAddresses.length;
    }

    function getAdmins() external view returns (address[] memory) {
        return adminAddresses;
    }

    function createElection(string calldata electionName)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(
            currentRound == 1 || electionMeta[currentRound - 1].electionPhase == 3,
            "Previous round not closed"
        );

        electionMeta[currentRound] = ElectionMeta({
            electionName: electionName,
            electionPhase: 0,
            totalCandidates: 0,
            totalRegisteredVoters: 0,
            totalVotesCast: 0,
            totalAdmins: electionMeta[1].totalAdmins
        });

        emit ElectionCreated(currentRound, electionName);
        currentRound++;
    }

    // Add a candidate with individual parameters
    function addCandidate(
        uint8 candidateId,
        string calldata candidateTitle,
        string calldata candidateFirstName,
        string calldata candidateLastName,
        string calldata candidateNickname,
        uint8 candidateAge,
        string calldata candidateBranch,
        uint8 candidatePartyNumber,
        string calldata candidatePartyName,
        string calldata candidatePolicy
    ) external onlyRole(ADMIN_ROLE) {
        ElectionMeta storage electionMetaData = electionMeta[currentRound];
        require(electionMetaData.electionPhase == 0, "Not in Setup Phase");
        require(
            !partyNameUsed[currentRound][candidatePartyName],
            "Party name already used"
        );
        require(candidateId > 0 && candidateId <= 255, "ID must be between 1 and 255");
        require(
            candidatePartyNumber > 0 && candidatePartyNumber <= 255,
            "Party number must be between 1 and 255"
        );
        require(candidates[currentRound][candidateId].candidateId == 0, "ID already taken");
        require(
            candidates[currentRound][candidatePartyNumber].candidatePartyNumber == 0,
            "Party number already taken"
        );

        Candidate memory newCandidate = Candidate({
            candidateId: candidateId,
            candidateTitle: candidateTitle,
            candidateFirstName: candidateFirstName,
            candidateLastName: candidateLastName,
            candidateNickname: candidateNickname,
            candidateAge: candidateAge,
            candidateBranch: candidateBranch,
            candidatePartyNumber: candidatePartyNumber,
            candidatePartyName: candidatePartyName,
            candidatePolicy: candidatePolicy,
            totalVotes: 0,
            timeAdded: block.timestamp
        });

        candidates[currentRound][candidateId] = newCandidate;
        partyNameUsed[currentRound][candidatePartyName] = true;
        if (candidateId > electionMetaData.totalCandidates) {
            electionMetaData.totalCandidates = candidateId;
        }

        emit CandidateAdded(currentRound, candidateId, candidatePartyName);
    }

    function setPhase(uint8 newPhase) external onlyRole(ADMIN_ROLE) {
        ElectionMeta storage electionMetaData = electionMeta[currentRound];
        require(newPhase == electionMetaData.electionPhase + 1, "Phase must advance");
        electionMetaData.electionPhase = newPhase;
        emit ElectionPhaseChanged(currentRound, newPhase);
    }

    /*======== Voter Functions ========*/

    function registerVoter(
        address voterAccount,
        string calldata studentId,
        string calldata voterTitle,
        string calldata voterFirstName,
        string calldata voterLastName,
        string calldata voterBranch
    ) external {
        ElectionMeta storage electionMetaData = electionMeta[currentRound];
        require(electionMetaData.electionPhase == 1, "Registration closed");

        require(isValidStudentId(studentId), "Invalid student ID format");
        require(
            !studentIdsUsed[currentRound][studentId],
            "Student ID already registered"
        );

        Voter storage voterData = voters[currentRound][voterAccount];
        require(!voterData.isRegistered, "Already registered");

        voterData.isRegistered = true;
        voterData.hasVotingToken = true;
        voterData.studentId = studentId;
        voterData.voterTitle = voterTitle;
        voterData.voterFirstName = voterFirstName;
        voterData.voterLastName = voterLastName;
        voterData.voterBranch = voterBranch;
        electionMetaData.totalRegisteredVoters++;

        studentIdsUsed[currentRound][studentId] = true;
        emit VoterRegistered(currentRound, voterAccount, studentId);
    }

    function vote(
        address voterAccount,
        string calldata studentId,
        uint8 candidatePartyNumber
    ) external {
        ElectionMeta storage electionMetaData = electionMeta[currentRound];
        require(electionMetaData.electionPhase == 2, "Voting closed");

        Voter storage voterData = voters[currentRound][voterAccount];
        require(voterData.isRegistered, "Not registered");
        require(
            keccak256(abi.encodePacked(voterData.studentId)) ==
                keccak256(abi.encodePacked(studentId)),
            "Student ID mismatch"
        );
        require(!voterData.hasVoted, "Already voted");
        require(voterData.hasVotingToken, "No voting token");

        Candidate storage candidateData = candidates[currentRound][candidatePartyNumber];
        require(candidateData.candidateId != 0, "Bad candidate");

        voterData.hasVoted = true;
        voterData.hasVotingToken = false;
        candidateData.totalVotes++;
        electionMetaData.totalVotesCast++;

        emit VoteCast(currentRound, voterAccount, candidatePartyNumber);
    }

    /*======== Read-only Helpers ========*/

    function getCandidate(uint256 round, uint8 candidateId)
        external
        view
        returns (Candidate memory)
    {
        return candidates[round][candidateId];
    }

    function getElectionMeta(uint256 round)
        external
        view
        returns (ElectionMeta memory)
    {
        return electionMeta[round];
    }

    function getAllCandidates(uint256 round)
        external
        view
        returns (uint8 totalCandidates, Candidate[] memory allCandidates)
    {
        uint8 candidateCount = electionMeta[round].totalCandidates;
        Candidate[] memory candidateList = new Candidate[](candidateCount);
        uint8 index = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[round][i].candidateId != 0) {
                candidateList[index] = candidates[round][i];
                index++;
            }
        }

        return (candidateCount, candidateList);
    }

    function getCandidateByPartyNumber(uint256 round, uint8 partyNumber)
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
            uint8 candidatePartyNumber,
            string memory candidatePartyName,
            string memory candidatePolicy,
            uint256 timeAdded
        )
    {
        Candidate storage candidate = candidates[round][partyNumber];
        require(candidate.candidateId != 0, "Candidate not found");

        return (
            candidate.candidateId,
            candidate.candidateTitle,
            candidate.candidateFirstName,
            candidate.candidateLastName,
            candidate.candidateNickname,
            candidate.candidateAge,
            candidate.candidateBranch,
            candidate.candidatePartyNumber,
            candidate.candidatePartyName,
            candidate.candidatePolicy,
            candidate.timeAdded
        );
    }

    function getAllPartyVotes(uint256 round)
        external
        view
        returns (PartyVoteResult[] memory partyVoteResults)
    {
        require(electionMeta[round].electionPhase == 3, "Election not closed");
        uint8 candidateCount = electionMeta[round].totalCandidates;
        PartyVoteResult[] memory voteList = new PartyVoteResult[](candidateCount);
        uint8 index = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[round][i].candidateId != 0) {
                voteList[index] = PartyVoteResult({
                    partyNumber: candidates[round][i].candidatePartyNumber,
                    voteCount: candidates[round][i].totalVotes
                });
                index++;
            }
        }

        return voteList;
    }

    function getWinningParty(uint256 round)
        external
        view
        returns (
            uint8 winningPartyNumber,
            string memory winningPartyName,
            uint256 highestVotes
        )
    {
        require(electionMeta[round].electionPhase == 3, "Election not closed");
        uint8 candidateCount = electionMeta[round].totalCandidates;

        uint8 winningPartyNumberTemp = 0;
        string memory winningPartyNameTemp = "";
        uint256 highestVotesTemp = 0;

        for (uint8 i = 1; i <= candidateCount; i++) {
            if (candidates[round][i].candidateId != 0) {
                uint256 currentVotes = candidates[round][i].totalVotes;
                if (currentVotes > highestVotesTemp) {
                    highestVotesTemp = currentVotes;
                    winningPartyNumberTemp = candidates[round][i].candidatePartyNumber;
                    winningPartyNameTemp = candidates[round][i].candidatePartyName;
                }
            }
        }

        require(winningPartyNumberTemp != 0, "No candidates found");
        return (winningPartyNumberTemp, winningPartyNameTemp, highestVotesTemp);
    }

    function getWinner(uint256 round)
        external
        view
        returns (
            uint8 winnerId,
            string memory winnerPartyName,
            uint256 votes
        )
    {
        require(electionMeta[round].electionPhase == 3, "Not closed");
        uint8 total = electionMeta[round].totalCandidates;

        for (uint8 i = 1; i <= total; ++i) {
            uint256 vc = candidates[round][i].totalVotes;
            if (vc > votes) {
                votes = vc;
                winnerId = i;
                winnerPartyName = candidates[round][i].candidatePartyName;
            }
        }
    }
}
