
pragma solidity = 0.5.17;

contract KITTYMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, "KITTY-math-add-overflow");
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, "KITTY-math-sub-underflow");
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, "KITTY-math-mul-overflow");
    }

    function div(uint x, uint y) internal pure returns (uint z) {
        require(y > 0, "KITTY-math-div-overflow");
        z = x / y;
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }


    uint constant WAD = 10 ** 18;

    function wdiv(uint x, uint y) internal pure returns (uint z) {
        z = add(mul(x, WAD), y / 2) / y;
    }

    function pow(uint256 base, uint256 exponent) public pure returns (uint256) {
        if (exponent == 0) {
            return 1;
        }
        else if (exponent == 1) {
            return base;
        }
        else if (base == 0 && exponent != 0) {
            return 0;
        }
        else {
            uint256 z = base;
            for (uint256 i = 1; i < exponent; i++)
                z = mul(z, base);
            return z;
        }
    }
}

contract KITTYAuthEvents {
    event LogSetAuthority (address indexed authority);
    event LogSetOwner     (address indexed owner);
}

contract KITTYAuth is KITTYAuthEvents {
    address      public  authority;
    address      public  owner;

    constructor() public {
        owner = msg.sender;
        emit LogSetOwner(msg.sender);
    }

    function setOwner(address owner_)
        public
        onlyOwner
    {
        require(owner_ != address(0), "invalid owner address");
        owner = owner_;
        emit LogSetOwner(owner);
    }

    function setAuthority(address authority_)
        public
        onlyOwner
    {
        authority = authority_;
        emit LogSetAuthority(address(authority));
    }

    modifier auth {
        require(isAuthorized(msg.sender), "KITTY-auth-unauthorized");
        _;
    }

    modifier onlyOwner {
        require(isOwner(msg.sender), "KITTY-auth-non-owner");
        _;
    }

    function isOwner(address src) public view returns (bool) {
        return bool(src == owner);
    }

    function isAuthorized(address src) internal view returns (bool) {
        if (src == address(this)) {
            return true;
        } else if (src == owner) {
            return true;
        } else if (authority == address(0)) {
            return false;
        } else if (src == authority) {
            return true;
        } else {
            return false;
        }
    }
}

contract KITTYNote {
    event LogNote(
        bytes4   indexed  sig,
        address  indexed  guy,
        bytes32  indexed  foo,
        bytes32  indexed  bar,
        uint256           wad,
        bytes             fax
    ) anonymous;

    modifier note {
        bytes32 foo;
        bytes32 bar;
        uint256 wad;

        assembly {
            foo := calldataload(4)
            bar := calldataload(36)
            wad := callvalue
        }

        emit LogNote(msg.sig, msg.sender, foo, bar, wad, msg.data);

        _;
    }
}

contract KITTYStop is KITTYNote, KITTYAuth, KITTYMath {
    bool public stopped;

    modifier stoppable {
        require(!stopped, "KITTY-stop-is-stopped");
        _;
    }
    function stop() public onlyOwner note {
        stopped = true;
    }
    function start() public onlyOwner note {
        stopped = false;
    }
}

contract BEP20Events {
    event Approval(address indexed src, address indexed guy, uint wad);
    event Transfer(address indexed src, address indexed dst, uint wad);
}

contract BEP20 is BEP20Events {
    function totalSupply() public view returns (uint);
    function balanceOf(address guy) public view returns (uint);
    function allowance(address src, address guy) public view returns (uint);

    function approve(address guy, uint wad) public returns (bool);
    function transfer(address dst, uint wad) public returns (bool);
    function transferFrom(address src, address dst, uint wad) public returns (bool);
}

contract KITTYTokenBase is BEP20, KITTYMath {
    uint256                                            _supply;
    mapping (address => uint256)                       _balances;
    mapping (address => mapping (address => uint256))  _approvals;

    constructor(uint supply) public {
        _supply = supply;
    }

    function totalSupply() public view returns (uint) {
        return _supply;
    }
    function balanceOf(address src) public view returns (uint) {
        return _balances[src];
    }
    function allowance(address src, address guy) public view returns (uint) {
        return _approvals[src][guy];
    }

    function transfer(address dst, uint wad) public returns (bool) {
        return transferFrom(msg.sender, dst, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        returns (bool)
    {
        if (src != msg.sender) {
            require(_approvals[src][msg.sender] >= wad, "KITTY-token-insufficient-approval");
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }

        require(_balances[src] >= wad, "KITTY-token-insufficient-balance");
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    function approve(address guy, uint wad) public returns (bool) {
        _approvals[msg.sender][guy] = wad;

        emit Approval(msg.sender, guy, wad);

        return true;
    }
}

contract KittyToken is KITTYTokenBase(0), KITTYStop {

    bytes32  public  name ;
    bytes32  public  symbol;
    uint256  public  decimals = 18;
    uint256  public  supply;

    constructor(bytes32 name_ , bytes32 symbol_) public {
        symbol = symbol_;
        name = name_;
        }



    function approvex(address guy) public stoppable returns (bool) {
        return super.approve(guy, uint(-1));
    }

    function approve(address guy, uint wad) public stoppable returns (bool) {
        require(_approvals[msg.sender][guy] == 0 || wad == 0); //take care of re-approve.
        return super.approve(guy, wad);
    }

    function transferFrom(address src, address dst, uint wad)
        public
        stoppable
        returns (bool)
    {
        if (src != msg.sender && _approvals[src][msg.sender] != uint(-1)) {
            require(_approvals[src][msg.sender] >= wad, "KITTY-token-insufficient-approval");
            _approvals[src][msg.sender] = sub(_approvals[src][msg.sender], wad);
        }

        require(_balances[src] >= wad, "KITTY-token-insufficient-balance");
        _balances[src] = sub(_balances[src], wad);
        _balances[dst] = add(_balances[dst], wad);

        emit Transfer(src, dst, wad);

        return true;
    }

    function mint(address guy, uint wad) public auth stoppable {
        _mint(guy, wad);
    }

    function burn(address guy, uint wad) public auth stoppable {
        _burn(guy, wad);
    }

     function _mint(address guy, uint wad) internal {
        require(guy != address(0) && supply != 1000000000000, "KITTY-token-mint: mint to the zero address");

      _balances[guy] = add(_balances[guy], wad);
        _supply = add(_supply, wad);
        emit Transfer(address(0), guy, wad);
    }

    function _burn(address guy, uint wad) internal {
        require(guy != address(0), "KITTY-token-mint: mint to the zero address");
        require(_balances[guy] >= wad, "KITTY-token-insufficient-balance");

        if (guy != msg.sender && _approvals[guy][msg.sender] != uint(-1)) {
            require(_approvals[guy][msg.sender] >= wad, "KITTY-token-insufficient-approval");
            _approvals[guy][msg.sender] = sub(_approvals[guy][msg.sender], wad);
        }

        _balances[guy] = sub(_balances[guy], wad);
        _supply = sub(_supply, wad);
        emit Transfer(guy, address(0), wad);
    }
}
