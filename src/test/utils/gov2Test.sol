// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "./MockERC20.sol";
import "./Hevm.sol";
import {Guild} from "../../guild.sol";
import {GuildCouncil} from "../../guildCouncil.sol";
import {MerchantRepublic} from "../../merchantRepublic.sol";
import {Constitution} from "../../constitution.sol";

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

    function mockEstablishGuild(address addr) public returns(uint256){
        setGuildCouncil(addr, address(guildCouncil));
        return guildCouncil.establishGuild(addr);
    }

    function setGuildCouncil(address guildAddress, address guildCouncilAddress)
        public
    {
        guild = Guild(guildAddress);
        guild.setGuildCouncil(guildCouncilAddress);
    }

    function sendBudgetToGuild(uint coins, address addr) public {
        mockDucat.transfer(addr, coins);
    }

    function withdrawBudget(uint coins, address guildAddr , address rec) public {
        guild = Guild(guildAddr);
        guild.withdraw(rec, coins);
    }

    function guildCouncilSetMerchantRepublic(address old, address newAddr) public {
        guildCouncil.setMerchantRepublic(old, newAddr);
    }

}

contract MockGuildCouncil is GuildCouncil{
    Guild guild;
    MockERC20 mockDucat;
    constructor(address mr, address ca, address ta) GuildCouncil(mr, ca, ta){}

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
        // emit log_address(address(this));
       //  emit log_named_uint("Guild set with id: ", guildId);
        guilds[guildId] = Guild(_g);
       //  emit log_address(address(guilds[guildId]));
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
                                       uint votingPeriod, uint votingDelay, uint propThres)
        public
    {
        mr.initialize(conAddr, tokAddr, gcAddr, votingPeriod, votingDelay, propThres);
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

    function castVoteForGuildMaster(uint8 support, address gm, uint48 guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForGuildMaster(support, gm);
    }

    function castVoteForBanishment(uint8 support, address target, uint guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForBanishment(support, target);
    }
    function guildCastVoteForProposal(uint8 support, uint48 proposalId, uint guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForProposal(proposalId, support);
    }
    function startBanishmentVote(address target, uint guild) public {
        Guild(guilds[guild]).startBanishmentVote(target);
    }
    function startGuildmasterVote(address gm, uint guild) public {
        Guild(guilds[guild]).startGuildmasterVote(gm);
    }
    function getVoteInfoGuildMaster(uint48 guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(1);
    }

    function getVoteInfoBanishment(uint guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(2);
    }

    function getVoteInfoProposal(uint guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(2);
    }

    function guildMasterAcceptanceCeremony(uint guild) public
        returns(bool)
    {
        return Guild(guilds[guild]).guildMasterAcceptanceCeremony();
    }

    function changeGravitasThreshold(uint guild, uint256 par) public  {
        Guild(guilds[guild]).changeGravitasThreshold(par);
    }

    function changeMemberRewardPerEpoch(uint guild, uint48 par) public  {
        Guild(guilds[guild]).changeMemberRewardPerEpoch(par);
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
}

contract Gov2Test is DSTestPlus {

    // solmate overrides

    string private checkpointLabel;
    uint256 private checkpointGasLeft;

    Guild internal guild;
    MockGuildCouncil internal guildCouncil;
    MerchantRepublic internal merchantRepublic;
    MockConstitution internal constitution;
    MockERC20 internal mockDucat;

    Commoner internal ursus;
    Commoner internal agnello;
    Commoner internal john;
    Commoner internal pipin;

    Guild internal locksmiths;
    Guild internal blacksmiths;
    Guild internal judges;
    Guild internal facelessGuild;

    uint256 agnelloDucats;
    uint256 johnDucats;
    uint256 ursusDucats;
    uint256 pipinDucats;

    uint32 locksmithsGT;
    uint32 blacksmithsGT;
    uint32 judgesGT;

    uint256 locksmithsId;
    uint256 blacksmithsId;
    uint256 judgesId;

    Commoner[] internal facelessMen;

    address[] internal guilds;

    function setUp() public virtual {
        ursus = new Commoner();
        agnello = new Commoner();
        john = new Commoner();
        pipin = new Commoner();

        // Create the ERC20 gov token
        mockDucat= new MockERC20("Ducat Token", "DK", 18);
        // Create the gov modules
        merchantRepublic = new MerchantRepublic(address(ursus));
        constitution = new MockConstitution(address(mockDucat));
        guildCouncil = new MockGuildCouncil(address(merchantRepublic), address(constitution), address(mockDucat));

        ursus.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        agnello.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        john.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        pipin.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        //delay = 2 days
        constitution.signTheConstitution(address(merchantRepublic), 2 days);
        constitution.mockProposals(address(guildCouncil), address(merchantRepublic));
        //votingPeriod = 1000 blocks
        //votingDelay = 450 blocks
        //proposalThreshold = 10

        ursus.initializeMerchantRepublic(address(constitution), address(mockDucat), address(guildCouncil),
                                        1000, 450, 1000);

        // set founding members for every guild
        // 0: locksmiths: ursus
        // 1: blacksmiths: agnello, ursus
        // 2: judges: john

        address[] memory founding1 = new address[](1);
        founding1[0] = address(ursus);
        address[] memory founding2 =  new address[](2);
        founding2[0] = address(agnello);
        founding2[1] = address(ursus);
        address[] memory founding3 = new address[](1);
        founding3[0] = address(john);

        // gravitas threshold to enter each guild
        locksmithsGT = 100;
        blacksmithsGT = 50;
        judgesGT = 500;

        locksmiths = new Guild("locksmiths", founding1, locksmithsGT, 14 days, 15, 7 days, address(mockDucat), address(constitution));
        blacksmiths = new Guild("blacksmiths", founding2, blacksmithsGT, 7 days, 50, 4 days, address(mockDucat), address(constitution));
        judges = new Guild("judges", founding3, judgesGT, 25 days, 5, 14 days, address(mockDucat), address(constitution));

        // Register the guilds with the GuildCouncil
        locksmithsId = constitution.mockEstablishGuild(address(locksmiths));
        blacksmithsId= constitution.mockEstablishGuild(address(blacksmiths));
        judgesId = constitution.mockEstablishGuild(address(judges));

        guilds = guildCouncil.availableGuilds();
        // register the guilds to the commoners
        for (uint48 i=0;i<guilds.length;i++){
           ursus.setGuild(guilds[i], i);
           john.setGuild(guilds[i], i);
           pipin.setGuild(guilds[i], i);
           agnello.setGuild(guilds[i], i);
        }
        assertEq(locksmithsId, 0);
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
        mockDucat.mint(address(agnello), agnelloDucats);
        mockDucat.mint(address(john), johnDucats);
        mockDucat.mint(address(pipin), pipinDucats);

        // Ursus is the Doge and sets the silver season
        ursus.setSilverSeason();
    }
}
