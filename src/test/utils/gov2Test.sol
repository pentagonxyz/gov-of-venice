// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "./Hevm.sol";
import {Guild} from "../../guild.sol";
import {GuildCouncil} from "../../guildCouncil.sol";
import {MerchantRepublic} from "../../merchantRepublic.sol";
import {Constitution} from "../../constitution.sol";

contract MockConstitution is Constitution {

    GuildCouncil guildCouncil;
    MerchantRepublic merchantRepublicContract;


    function mockProposals(address gc, address mr) public {
        guildCouncil = GuildCouncil(gc);
        merchantRepublicContract = MerchantRepublic(mr);
    }

    function mockEstablishGuild(address guild) public returns(uint256){
        setGuildCouncil(guild, address(guildCouncil));
        return guildCouncil.establishGuild(guild);
    }

    function setGuildCouncil(address guildAddress, address guildCouncilAddress)
        public
    {
        Guild guild = Guild(guildAddress);
        guild.setGuildCouncil(guildCouncilAddress);
    }

}

contract Commoner is DSTestPlus{
    Guild internal g;
    GuildCouncil internal gc;
    MerchantRepublic internal mr;
    MockConstitution internal con;
    MockERC20 internal md;

    mapping(uint256 => Guild) guilds;

    constructor(){}

    function init( address _gc, address _mr, address _con, address _md)
        public
    {
        gc = GuildCouncil(_gc);
        mr = MerchantRepublic(_mr);
        con = MockConstitution(_con);
        md = MockERC20(_md);
    }

    function setGuild(address _g, uint256 guildId)
        public
    {
        // emit log_address(address(this));
       //  emit log_named_uint("Guild set with id: ", guildId);
        guilds[guildId] = Guild(_g);
       //  emit log_address(address(guilds[guildId]));
    }

    function sendSilver(address rec, uint256 amount, uint256 guildId)
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

    function getGravitas(uint256 guildId)
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

    function startApprentiship(uint guild) public {
        Guild(guilds[guild]).startApprentiship();
    }
    function joinGuild(uint guild) public returns (Guild.GuildMember memory){
        return Guild(guilds[guild]).joinGuild();
    }
    function isGuildMember(uint guild) public returns(bool) {
        return Guild(guilds[guild]).isGuildMember(address(this));
    }

    function castVoteForGuildMaster(uint8 support, address gm, uint guild) public returns(bool){
        return Guild(guilds[guild]).castVoteForGuildMaster(support, gm);
    }
    function startGuildmasterVote(address gm, uint guild) public {
        Guild(guilds[guild]).startGuildmasterVote(gm);
    }
    function getVoteInfoGuildMaster(uint guild) public
        returns(uint48, uint48, uint48,
                uint88, bool, address, address,
                uint256)
    {
       return Guild(guilds[guild]).getVoteInfo(1);
    }

    function guildMasterAcceptanceCeremony(uint guild) public
        returns(bool)
    {
        return Guild(guilds[guild]).guildMasterAcceptanceCeremony();
    }

}

contract Gov2Test is DSTestPlus {

    // solmate overrides

    string private checkpointLabel;
    uint256 private checkpointGasLeft;

    Guild internal guild;
    GuildCouncil internal guildCouncil;
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
        constitution = new MockConstitution();
        guildCouncil = new GuildCouncil(address(merchantRepublic), address(constitution), address(mockDucat));

        ursus.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        agnello.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        john.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));
        pipin.init(address(guildCouncil), address(merchantRepublic), address(constitution), address(mockDucat));

        constitution.signTheConstitution(address(merchantRepublic), 2 days);
        constitution.mockProposals(address(guildCouncil), address(merchantRepublic));
        ursus.initializeMerchantRepublic(address(constitution), address(mockDucat), address(guildCouncil), 14 days, 2 days, 10);

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
        uint256 locksmithsId = constitution.mockEstablishGuild(address(locksmiths));
        uint256 blacksmithsId= constitution.mockEstablishGuild(address(blacksmiths));
        uint256 judgesId = constitution.mockEstablishGuild(address(judges));

        guilds = guildCouncil.availableGuilds();
        // register the guilds to the commoners
        for (uint i=0;i<guilds.length;i++){
           ursus.setGuild(guilds[i], i);
           john.setGuild(guilds[i], i);
           pipin.setGuild(guilds[i], i);
           agnello.setGuild(guilds[i], i);
        }
        assertEq(locksmithsId, 0);
        assertEq(blacksmithsId, 1);
        assertEq(judgesId, 2);

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
