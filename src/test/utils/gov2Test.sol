import {DSTestPlus} from "solmate/test/utils/DSTestPlus.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import "./Hevm.sol"
import {Guild} from "../../guild.sol";
import {GuildCouncil} from "../../guildCouncil.sol";
import {MerchantRepublic} from "../../merchantRepublic.sol";
import {Constitution} from "../../constitution.sol";


contract Commoner{
    Guild internal g;
    GuildCouncil internal gc;
    MerchantRepublic internal mr;
    Constitution internal con;
    MockERC20 internal md;

    constructor(){}

    init(address _g, address _gc, address _mr, address _con, address _md){
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

        mockDucat= new MockERC20("Ducat Token" "DK", 18);
        merchantRepublic = new MerchantRepublic();
        constitution = new Constitution(address(merchantRepublic), 2 days);
        guildCouncil = new GuildCouncil(address(merchantRepublic), address(guildCouncil), address(mockDucat));
    }
}
