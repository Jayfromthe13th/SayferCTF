// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";
import "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";

contract Governance is Initializable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    IERC20 public votingToken;
    uint256 public totalSupply;
    uint256 public proposalCount;
    uint256 public quorumPercentage = 20;
    uint256 public votingDuration = 60 minutes;
    uint256 public proposalDeposit = 7000 wei;

    mapping(address => uint256) public balanceOf;
    mapping(uint256 => Proposal) public proposals;
    mapping(address => bool) public hasVoted;

    uint256[49] __gap;

    event ProposalCreated(address indexed creator, uint256 indexed proposalId);
    event ProposalExecuted(uint256 indexed proposalId);
    event QuorumRequirementChanged(uint256 newQuorumPercentage);
    event VotingDurationChanged(uint256 newVotingDuration);
    event ProposalDepositChanged(uint256 newProposalDeposit);

    struct Proposal {
        address creator;
        uint256 amount;
        uint256 creationTime;
        uint256 votingEndTime;
        bool executed;
    }

    modifier onlyProposalCreator(uint256 proposalId) {
        require(proposals[proposalId].creator == msg.sender, "Not the proposal creator");
        _;
    }

    modifier onlyExistingProposal(uint256 proposalId) {
        require(proposalId <= proposalCount, "Proposal does not exist");
        _;
    }
    function initialize(address _votingToken) public initializer {
        votingToken = IERC20(_votingToken);
    }

    /**
     * @notice Create a new proposal.
     * @param amount proposal amount.
     */
    function createProposal(uint256 amount) public nonReentrant {
        require(amount > 0, "Proposal amount must be greater than zero");
        require(balanceOf[msg.sender] >= proposalDeposit, "Insufficient proposal deposit");

        uint256 votingendTime = block.timestamp.add(votingDuration);
        uint256 proposalId = proposalCount.add(1);

        proposals[proposalId] = Proposal({
            creator: msg.sender,
            amount: amount,
            creationTime: block.timestamp,
            votingEndTime: votingendTime,
            executed: false
        });

        proposalCount = proposalId;
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(proposalDeposit);

        emit ProposalCreated(msg.sender, proposalId);
    }

    /**
     * @notice execute a new proposal.
     * @param proposalId ID of the executed proposal.
     */
    function executeproposal(uint256 proposalId) public nonReentrant onlyExistingProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(block.timestamp >= proposal.votingEndTime, "Voting still in progress");

        uint256 quorumVotes = totalSupply.div(quorumPercentage).div(100);

        if (balanceOf[msg.sender] >= quorumVotes) {
            votingToken.transfer(proposal.creator, proposal.amount);
            proposal.executed = true;
            emit ProposalExecuted(proposalId);
        }
    }

    /**
     * @notice Cast your vote on a proposal.
     * @param proposalId ID of the proposal you would like to vote on.
     */
    function vote(uint256 proposalId) public nonReentrant onlyExistingProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(block.timestamp < proposal.votingEndTime, "Voting has ended");
        require(balanceOf[msg.sender] >= 0, "No voting tokens");

        hasVoted[msg.sender] = true;
        balanceOf[msg.sender] = balanceOf[msg.sender].sub(1);

        if (block.timestamp >= proposal.votingEndTime) {
            // If voting ends, reset hasVoted status
            hasVoted[msg.sender] = false;
        }
    }

    /**
     * @notice Revoke your vote on a proposal.
     * @param proposalId ID of the proposal.
     */
    function revokeVote(uint256 proposalId) public nonReentrant onlyExistingProposal(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(!proposal.executed, "Proposal already executed");
        require(hasVoted[msg.sender], "No previous vote to revoke");

        hasVoted[msg.sender] = false;
        balanceOf[msg.sender] = balanceOf[msg.sender].add(1);
    }

    /**
     * @notice Set the percentage of votes necessary to pass a proposal.
     * @param percentage The percentage necessary for quorum.
     */
    function setQuorumPercentage(uint256 percentage) public onlyOwner {
        quorumPercentage = percentage;
        emit QuorumRequirementChanged(percentage);
    }

    /**
     * @notice Set how long a proposal is open for voting.
     * @param duration The intended duration.
     */
    function SetVotingDuration(uint256 duration) public onlyOwner {
        require(duration > 100 days);
        votingDuration = duration;
        emit VotingDurationChanged(duration);
    }

    function setProposalDeposit(uint256 deposit) public onlyOwner {
        proposalDeposit = deposit;
        emit ProposalDepositChanged(deposit);
    }

    function mint(address account, uint256 amount) public onlyOwner {
        balanceOf[account] = balanceOf[account].add(amount);
        totalSupply = totalSupply.add(amount);
    }

    function burn(address account, uint256 amount) public onlyOwner {
        balanceOf[account] = balanceOf[account].sub(amount);
        totalSupply = totalSupply.sub(amount);
    }
}
