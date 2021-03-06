// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./MockERC20.sol";
import "./Hevm.sol";
import {Guild} from "../../Guild.sol";
import {GuildCouncil} from "../../GuildCouncil.sol";
import {MerchantRepublic} from "../../MerchantRepublic.sol";
import {Constitution} from "../../Constitution.sol";
import {ProposalTarget} from "./proposalTarget.sol";

contract MockConstitution is Constitution {

    GuildCouncil guildCouncil;
    MerchantRepublic merchantRepublicContract;
    Guild guild;
    MockERC20 mockDucat;

    constructor(address md){
        mockDucat = MockERC20(md);
    }

    function mockProposals(address gc, address mr) public {
        guildCouncil = GuildCouncil(gc);
        merchantRepublicContract = MerchantRepublic(mr);
    }

    function mockEstablishGuild(address addr, uint48 minDecisionTime) public returns(uint48){
        return guildCouncil.establishGuild(addr, minDecisionTime);
    }

    function sendBudgetToGuild(uint coins, address addr) public {
        mockDucat.transfer(addr, coins);
    }

    function withdrawBudget(uint coins, address guildAddr , address rec) public {
        guild = Guild(guildAddr);
        guild.withdraw(rec, coins);
    }

    function guildCouncilSetMerchantRepublic(address old, address newAddr) public {
        guildCouncil.setMerchantRepublic(newAddr);
    }

}

contract MockGuildCouncil is GuildCouncil{
    Guild guild;
    MockERC20 mockDucat;
    constructor(address mr, address ca, address ta) GuildCouncil(mr, ca){}

    function mockCallGuildProposal(address guildAddress, uint48 proposalId) public {
        guild = Guild(guildAddress);
        guild.guildVoteRequest(proposalId);
    }

    function mockGuildsVerdict(uint48 proposalId, bool verdict) public {
        merchantRepublic.guildsVerdict(proposalId, verdict);
    }

}


contract Commoner is DSTestPlus{
    Guild internal g;
    GuildCouncil internal gc;
    MerchantRepublic internal mr;
    MockConstitution internal con;
    MockERC20 internal md;

    mapping(uint256 => Guild) guilds;


    function init( address _gc, address _mr, address _con, address _md)
        public
    {
        gc = GuildCouncil(_gc);
        mr = MerchantRepublic(_mr);
        con = MockConstitution(_con);
        md = MockERC20(_md);
    }

    function setGuild(address _g, uint48 guildId)
        public
    {
        guilds[guildId] = Guild(_g);
    }

    function sendSilver(address rec, uint256 amount, uint48 guildId)
        public
        returns(uint256)
    {
        return mr.sendSilver(rec, amount, guildId);
    }

    function setSilverSeason()
        public
        returns(bool)
    {
        return mr.setSilverSeason();
    }

    function silverBalance()
        public
        returns(uint256)
    {
        return mr.silverBalance();
    }

    function getGravitas(uint48 guildId)
        public
        returns(uint256)
    {
        return guilds[guildId].getGravitas(address(this));
    }

    function initializeMerchantRepublic(address conAddr, address tokAddr, address gcAddr,
                                       uint48 guildvotemax, uint votingPeriod, uint votingDelay, uint propThres)
        public
    {
        mr.initialize(conAddr, tokAddr, gcAddr, guildvotemax, votingPeriod, votingDelay, propThres);
        mr._initiate(address(0));
    }

    function startApprentiship(uint48 guild) public {
        Guild(guilds[guild]).startApprentiship();
    }
    function joinGuild(uint48 guild) public returns (Guild.GuildMember memory){
        return Guild(guilds[guild]).joinGuild();
    }
    function isGuildMember(uint48 guild) public returns(bool) {
        return Guild(guilds[guild]).isGuildMember(address(this));
    }

    function castVoteForGuildMaster(uint8 support, uint48 guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForGuildMaster(support);
    }

    function castVoteForBanishment(uint8 support,uint guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForBanishment(support);
    }
    function guildCastVoteForProposal(uint8 support, uint48 proposalId, uint guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForProposal(proposalId, support, address(gc));
    }
    function startBanishmentVote(address target, uint guild) public {
        Guild(guilds[guild]).startBanishmentVote(target);
    }
    function startGuildmasterVote(address gm, uint guild) public {
        Guild(guilds[guild]).startGuildMasterVote(gm);
    }
    function getVoteInfoGuildMaster(uint48 guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(1, address(0), 0);
    }

    function getVoteInfoBanishment(uint guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(2, address(0), 0);
    }

    function getVoteInfoProposal(uint guild, uint48 id) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(2, address(gc), id);
    }

    function guildMasterAcceptanceCeremony(uint guild) public
        returns(bool)
    {
        return Guild(guilds[guild]).guildMasterAcceptanceCeremony();
    }

    function changeGravitasThreshold(uint guild, uint256 par) public  {
        Guild(guilds[guild]).changeGravitasThreshold(par);
    }

    function changeMemberRewardPerSecond(uint guild, uint48 par) public  {
        Guild(guilds[guild]).changeMemberRewardPerSecond(par);
    }

    function changeGuildMasterMultiplier(uint guild, uint8 par) public  {
        Guild(guilds[guild]).changeGuildMasterMultiplier(par);
    }

    function changeMaxGuildMembers(uint guild, uint256 par) public  {
        Guild(guilds[guild]).changeMaxGuildMembers(par);
    }

    function changeGuildMemberSlash(uint guild, uint256 par) public  {
        Guild(guilds[guild]).changeGuildMemberSlash(par);
    }
    function changeSlashForCashReward(uint guild, uint256 par) public {
        Guild(guilds[guild]).changeSlashForCashReward(par);
    }

    function claimReward(uint guild) public {
        Guild(guilds[guild]).claimReward();
    }
    function calculateMemberReward(uint guild) public returns(uint) {
        return Guild(guilds[guild]).calculateMemberReward(address(this));
    }
    function govCastVote(uint48 id, uint8 support) public {
        mr.castVote(id, support);
    }

    function queueProposal(uint48 id) public {
        mr.queue(id);
    }

    function executeProposal(uint48 id) public {
        mr.execute(id);
    }

    function govPropose(address[] calldata targets, uint[] calldata values,
                        string[] calldata signatures, bytes[] calldata calldatas,
                     string calldata description, uint48[] calldata guildsId) public returns(uint48)
    {
        return mr.propose(targets, values, signatures, calldatas, description, guildsId);
    }
    function govCancel(uint48 id) public {
        mr.cancel(id);
    }

    function govSetVotingDelay(uint delay) public {
        mr._setVotingDelay(delay);
    }

    function govSetProposalThreshold(uint th) public {
        mr._setProposalThreshold(th);
    }
    function govSetVotingPeriod(uint period) public {
        mr._setVotingPeriod(period);
    }
    function govSetPendingDoge(address doge) public {
        mr._setPendingDoge(doge);
    }
    function govAcceptDoge() public {
        mr._acceptDoge();
    }

    function setGuildCouncil(address guildAddress, address guildCouncilAddress,
                             uint256 silverRatio, uint48 guildId)
        public
    {
        Guild guild = Guild(guildAddress);
        guild.setGuildCouncil(guildCouncilAddress, silverRatio,  guildId);
    }
}

contract Gov2Test is DSTestPlus {

    string private checkpointLabel;
    uint256 private checkpointGasLeft;

    Guild internal guild;
    MockGuildCouncil internal guildCouncil;
    MerchantRepublic internal merchantRepublic;
    MockConstitution internal constitution;
    MockERC20 internal mockDucat;
    MockGuildCouncil internal guildCouncilPopuli;
    MerchantRepublic internal merchantRepublicPopuli;
    MockConstitution internal constitutionPopuli;
    MockERC20 internal mockDucatPopuli;

    Commoner internal ursus;
    Commoner internal agnello;
    Commoner internal john;
    Commoner internal pipin;
    Commoner internal ezio;
    Commoner internal machiavelli;

    Guild internal locksmiths;
    Guild internal blacksmiths;
    Guild internal judges;
    Guild internal facelessGuild;

    uint256 agnelloDucats;
    uint256 johnDucats;
    uint256 ursusDucats;
    uint256 pipinDucats;

    uint32 locksmithsGT;
    uint32 locksmithsPopuliGT;
    uint32 blacksmithsGT;
    uint32 judgesGT;

    uint48 locksmithsId;
    uint48 locksmithsPopuliId;
    uint48 blacksmithsId;
    uint48 judgesId;

    Commoner[] internal facelessMen;
    Commoner[] internal commoners;
    Commoner[] internal facelessWomen;
    Commoner[] internal populi;

    ProposalTarget proposalTarget;

    address[] internal guilds;
    address[] internal guildsPopuli;


    function setUp() public virtual {

        ursus = new Commoner();
        agnello = new Commoner();
        john = new Commoner();
        pipin = new Commoner();
        ezio = new Commoner();
        machiavelli = new Commoner();

        // Create the ERC20 gov token
        mockDucat = new MockERC20("Ducat Token", "DK", 18);
        mockDucatPopuli = new MockERC20("Populi Ducat Token", "PDK", 18);

        // Create the gov modules
        merchantRepublic = new MerchantRepublic(address(ursus));
        constitution = new MockConstitution(address(mockDucat));
        guildCouncil = new MockGuildCouncil(address(merchantRepublic), address(constitution), address(mockDucat));

        merchantRepublicPopuli = new MerchantRepublic(address(machiavelli));
        constitutionPopuli = new MockConstitution(address(mockDucatPopuli));
        guildCouncilPopuli = new MockGuildCouncil(address(merchantRepublicPopuli), address(constitutionPopuli), address(mockDucatPopuli));

        ursus.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        ezio.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        agnello.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        john.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        pipin.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        machiavelli.init(address(guildCouncilPopuli), address(merchantRepublicPopuli), address(constitutionPopuli), address(mockDucatPopuli));

        constitution.signTheConstitution(address(merchantRepublic), 2 days);
        constitution.mockProposals(address(guildCouncil), address(merchantRepublic));

        constitutionPopuli.signTheConstitution(address(merchantRepublicPopuli), 2 days);
        constitutionPopuli.mockProposals(address(guildCouncilPopuli), address(merchantRepublicPopuli));

        // Merchant Republic
        // votingPeriod = 7 days
        // votingDelay =  2 days
        // proposalThreshold = 10

       //guildsMaxVotingPeriod, votingPeriod, votingDelay, proposalThreshold
        ursus.initializeMerchantRepublic(address(constitution), address(mockDucat), address(guildCouncil),
                                        3 days, 7 days, 2 days , 10);
        machiavelli.initializeMerchantRepublic(address(constitutionPopuli), address(mockDucatPopuli), address(guildCouncilPopuli),
                                        3 days, 7 days, 2 days , 10);

        // set founding members for every guild for Merchant Republic
        // 0: locksmiths: ursus, ezio
        // 1: blacksmiths: agnello, ursus
        // 2: judges: john

        // set founding members for every guild for Populi Merchant Republic (another instance)
        // 0: locksmiths: ursus, ezio

        address[] memory founding1 = new address[](3);
        founding1[0] = address(ursus);
        founding1[1] = address(ezio);
        founding1[2] = address(machiavelli);
        address[] memory founding2 =  new address[](2);
        founding2[0] = address(agnello);
        founding2[1] = address(ursus);
        address[] memory founding3 = new address[](1);
        founding3[0] = address(john);

        // gravitas threshold to enter each guild
        locksmithsGT = 100;
        blacksmithsGT = 50;
        judgesGT = 500;

        locksmiths = new Guild("locksmiths", founding1, locksmithsGT, 14 days, 15, 7 days, address(mockDucat));
        blacksmiths = new Guild("blacksmiths", founding2, blacksmithsGT, 7 days, 50, 4 days, address(mockDucat));
        judges = new Guild("judges", founding3, judgesGT, 25 days, 5, 14 days, address(mockDucat));

        // Register the guilds with the GuildCouncil  of every merchant republic
        // The guild might have differrent guildId in different Guild Councils

        uint48 MINIMUM_DECISION_TIME = 2 days;

        locksmithsId = constitution.mockEstablishGuild(address(locksmiths), MINIMUM_DECISION_TIME);
        blacksmithsId= constitution.mockEstablishGuild(address(blacksmiths), MINIMUM_DECISION_TIME);
        judgesId = constitution.mockEstablishGuild(address(judges), MINIMUM_DECISION_TIME);
        locksmithsPopuliId = constitutionPopuli.mockEstablishGuild(address(locksmiths), MINIMUM_DECISION_TIME);

        // Register the guilld council with the Guilds
        // Only the Guild master can perform this. The first member of the founding member
        // array becomes the first guild master of the guild.
        ursus.setGuildCouncil(address(locksmiths), address(guildCouncil), 10, locksmithsId);
        ursus.setGuildCouncil(address(locksmiths), address(guildCouncilPopuli), 10, locksmithsId);
        agnello.setGuildCouncil(address(blacksmiths), address(guildCouncil), 10, blacksmithsId);
        john.setGuildCouncil(address(judges), address(guildCouncil), 10, judgesId);

        guilds = guildCouncil.availableGuilds();
        guildsPopuli = guildCouncilPopuli.availableGuilds();

        // register the guilds to the commoners contract for testing
        for (uint48 i=0;i<guilds.length;i++){
           ursus.setGuild(guilds[i], i);
           john.setGuild(guilds[i], i);
           pipin.setGuild(guilds[i], i);
           agnello.setGuild(guilds[i], i);
           ezio.setGuild(guilds[i], i);
           machiavelli.setGuild(guilds[i], i);
        }
        assertEq(locksmithsId, 0);
        assertEq(locksmithsPopuliId, 0);
        assertEq(blacksmithsId, 1);
        assertEq(judgesId, 2);

        assertTrue(ursus.isGuildMember(0));
        assertTrue(agnello.isGuildMember(1));
        assertTrue(ursus.isGuildMember(1));
        assertTrue(john.isGuildMember(2));

        // mint $ducats
        ursusDucats = 10000;
        agnelloDucats = 20000;
        johnDucats = 10000;
        pipinDucats = 500;
        mockDucat.mint(address(ursus), ursusDucats);
        mockDucat.mint(address(ezio), ursusDucats);
        mockDucatPopuli.mint(address(machiavelli), ursusDucats);
        mockDucat.mint(address(agnello), agnelloDucats);
        mockDucat.mint(address(john), johnDucats);
        mockDucat.mint(address(pipin), pipinDucats);
        // Ursus is the Doge and sets the silver season
        ursus.setSilverSeason();
        // Ezio is the Doge for the Populi Merchant Republic and sets
        // the silver season
        machiavelli.setSilverSeason();
    }

    function initCommoners() public {
        uint256 startingBalance = 100000e18;
        commoners = new Commoner[](30);
        for (uint256 i; i < 30; i++) {
            commoners[i] = new Commoner();
            commoners[i].init(
                address(guildCouncil),
                address(merchantRepublic),
                address(constitution),
                address(mockDucat)
            );
            mockDucat.mint(address(commoners[i]), startingBalance);
        }
    }

    function initPopuli() public {
        uint256 startingBalance = 100000e18;
        populi = new Commoner[](30);
        for (uint256 i; i < 30; i++) {
            populi[i] = new Commoner();
            populi[i].init(
                address(guildCouncilPopuli),
                address(merchantRepublicPopuli),
                address(constitutionPopuli),
                address(mockDucatPopuli)
            );
            mockDucatPopuli.mint(address(populi[i]), startingBalance);
        }
    }

    function initMembers() public {
        uint32 facelessGravitasThreshold = 400;
        uint32 facelessTimeOutPeriod = 25 days;
        uint32 facelessMaxGuildMembers = 20;
        uint32 facelessVotingPeriod = 14 days;
        facelessMen = new Commoner[](20);
        address[] memory facelessAddresses = new address[](20);
        uint256 ducats = 10000000;
        for (uint256 i = 0; i < facelessMen.length; i++) {
            facelessMen[i] = new Commoner();
            facelessMen[i].init(
                address(guildCouncil),
                address(merchantRepublic),
                address(constitution),
                address(mockDucat)
            );
            facelessAddresses[i] = address(facelessMen[i]);
            for (uint48 j = 0; j < guilds.length; j++) {
                facelessMen[i].setGuild(guilds[j], j);
            }
            mockDucat.mint(address(facelessMen[i]), ducats);
        }
        facelessGuild = new Guild(
            "faceless",
            facelessAddresses,
            facelessGravitasThreshold,
            facelessTimeOutPeriod,
            facelessMaxGuildMembers,
            facelessVotingPeriod,
            address(mockDucat)
        );
        uint48 id = constitution.mockEstablishGuild(address(facelessGuild), 2 days);
        facelessMen[0].setGuildCouncil(address(facelessGuild), address(guildCouncil), 10, id);
        guilds = guildCouncil.availableGuilds();
        for (uint256 i = 0; i < facelessMen.length; i++) {
            facelessMen[i].setGuild(guilds[3], 3);
        }
    }

    function createProposalTarget() public {
        proposalTarget = new ProposalTarget();
        assertTrue(proposalTarget.flag());
    }


}
