import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "./Hevm.sol";
import {Guild} from "../../guild.sol";
import {GuildCouncil} from "../../guildCouncil.sol";
import {MerchantRepublic} from "../../merchantRepublic.sol";
import {Constitution} from "../../constitution.sol";

contract mockConstitution is Constitution {

    GuildCouncil guildCouncil;
    MerchantRepublic merchantRepublic;


    function mockProposals(address gc, address gc){
        guildCouncil = GuildCouncil(gc);
        merchantRepublic = MerchantRepublic(mr);
    }

    function mockEstablishGuild(address guild){
        guildCouncil.establishGuild(guild);
    }

}

contract Commoner{
    Guild internal g;
    GuildCouncil internal gc;
    MerchantRepublic internal mr;
    Constitution internal con;
    MockERC20 internal md;

    constructor(){}

    function init(address _g, address _gc, address _mr, address _con, address _md){
        g = Guild(_g);
        gc = Guildcouncil(_gc);
        mr = MerchantRepublic(_mr);
        con = Constitution(_con);
        md = MockERC20(_md);
    }
}
contract Gov2Test is DSTestPlus {

    Guild internal guild;
    GuildCouncil internal guildCouncil;
    MerchantRepublic internal merchantRepublic;
    Constitution internal constitution;
    MockERC20 internal mockERC20;

    Commoner internal ursus;
    Commoner internal agnello;
    Commoner internal john;
    Commoner internal pipin;

    Guild internal locksmiths;
    Guild internal blacksmiths;
    Guidl internal judges;

    function setUp() public virtual {
        ursus = new Commoner();
        agnello = new Commoner();
        john = new Commoner();
        pipin = new Commoner();

        // Create the ERC20 gov token
        mockDucat= new MockERC20("Ducat Token" "DK", 18);
        // Create the gov modules
        merchantRepublic = new MerchantRepublic();
        constitution = new mockConstitution();
        guildCouncil = new GuildCouncil(address(merchantRepublic), address(guildCouncil), address(mockDucat));
        constitution.signTheConstitution(address(merchantRepublic), 2 days);
        constitution.mockProposals(address(guildCouncil), address(merchantRepublic));

        locksmiths = new Guild("locksmiths", 100, 14 days, 15, 7 days);
        blacksmiths = new Guild("blacksmiths", 50, 7 days, 50, 4 days);
        judges = new Guild("judges", 400, 25 days, 5, 14 days);

        // Register the guilds with the GuildCouncil
        constitution.mockEstablishGuild(address(locksmiths));
        constitution.mockEstablishGuild(address(blacksmiths));
        constitution.mockEstablishGuild(address(judges));

    }
}
