pragma solidity ^0.4.18;



library LibCLLu {

    string constant public VERSION = "LibCLLu 0.4.0";
    uint constant public NULL = 0;
    uint constant public HEAD = 0;
    bool constant public PREV = false;
    bool constant public NEXT = true;
    
    struct CLL{
        mapping (uint => mapping (bool => uint)) cll;
    }

    // n: node id  d: direction  r: return node id

    // Return existential state of a list.
    function exists(CLL storage self)
        internal
        constant returns (bool)
    {
        if (self.cll[HEAD][PREV] != HEAD || self.cll[HEAD][NEXT] != HEAD)
            return true;
    }
    
    // Returns the number of elements in the list
    function sizeOf(CLL storage self) internal constant returns (uint r) {
        uint i = step(self, HEAD, NEXT);
        while (i != HEAD) {
            i = step(self, i, NEXT);
            r++;
        }
        return;
    }

    // Returns the links of a node as and array
    function getNode(CLL storage self, uint n)
        internal  constant returns (uint[2])
    {
        return [self.cll[n][PREV], self.cll[n][NEXT]];
    }

    // Returns the link of a node `n` in direction `d`.
    function step(CLL storage self, uint n, bool d)
        internal  constant returns (uint)
    {
        return self.cll[n][d];
    }

    // Can be used before `insert` to build an ordered list
    // `a` an existing node to search from, e.g. HEAD.
    // `b` value to seek
    // `r` first node beyond `b` in direction `d`
    function seek(CLL storage self, uint a, uint b, bool d)
        internal  constant returns (uint r)
    {
        r = step(self, a, d);
        while  ((b!=r) && ((b < r) != d)) r = self.cll[r][d];
        return;
    }

    // Creates a bidirectional link between two nodes on direction `d`
    function stitch(CLL storage self, uint a, uint b, bool d) internal  {
        self.cll[b][!d] = a;
        self.cll[a][d] = b;
    }

    // Insert node `b` beside existing node `a` in direction `d`.
    function insert (CLL storage self, uint a, uint b, bool d) internal  {
        uint c = self.cll[a][d];
        stitch (self, a, b, d);
        stitch (self, b, c, d);
    }
    
    function remove(CLL storage self, uint n) internal returns (uint) {
        if (n == NULL) return;
        stitch(self, self.cll[n][PREV], self.cll[n][NEXT], NEXT);
        delete self.cll[n][PREV];
        delete self.cll[n][NEXT];
        return n;
    }

    function push(CLL storage self, uint n, bool d) internal  {
        insert(self, HEAD, n, d);
    }
    
    function pop(CLL storage self, bool d) internal returns (uint) {
        return remove(self, step(self, HEAD, d));
    }
}


library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

interface ERC20 {
    function totalSupply() public view returns (uint256 supply);
    function balanceOf( address who ) public view returns (uint256 value);
    function allowance( address owner, address spender ) public view returns (uint256 _allowance);

    function transfer( address to, uint256 value) public returns (bool ok);
    function transferFrom( address from, address to, uint value) public returns (bool ok);
    function approve( address spender, uint256 value ) public returns (bool ok);

    function decimals() public view returns (uint8 dec);
    
    event Transfer( address indexed from, address indexed to, uint256 value);
    event Approval( address indexed owner, address indexed spender, uint256 value);
}

contract FrozenTokenHolder {
    using SafeMath for uint256;

    address public owner = msg.sender;
    ERC20 public BKXtoken;

    uint256 public totalInternalSupply = 0;
    uint256 public totalDistributed = 0;
    uint256 public defaultFreezeTime = 365 days;
    string public name = "BankexUtility";
    string public symbol = "BKXU";
    uint8 public decimals = 9;
    mapping(address => bool) public allowedReceivers;

    using LibCLLu for LibCLLu.CLL;
    mapping (address => LibCLLu.CLL) balanceLists;
    mapping (address => mapping(uint256 => BalanceStructure)) balanceStructures;
    mapping (address => uint256) lastPushedIndexes;
    
    // event DebugLog(bool indexed b, uint256 indexed ui, address indexed add);
    
    struct BalanceStructure{
        uint256 balance;
        uint256 fronzenAt;
        uint256 freezeTime;
        bool frozen;
    }

    // Ownership

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) public onlyOwner returns (bool success) {
        require(newOwner != address(0));      
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        return true;
    }


    // ERC20 related functions

    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) allowed;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    
    
    function findAndSubtractForTransfer(address _from, address _to, uint256 _value) internal returns (bool success) {
        LibCLLu.CLL storage bList = balanceLists[_from];
        uint256 amountLeftToSupport = _value;
        bool requireUnfrozen = !allowedReceivers[_to];
        uint256 node;
        uint256 size = bList.sizeOf();
        uint256[] memory nodesToRemove = new uint256[](size);
        uint256 removalIndex = 0;
        for (uint256 i = 0; i < size; i++) {
            if (i == 0) {
                node = bList.step(0, false);
            } else {
                node = bList.step(node, false);
            }
            BalanceStructure storage bStruct = balanceStructures[_from][node];
            if (requireUnfrozen) {
                if (bStruct.frozen) {
                    if (now < (bStruct.fronzenAt + bStruct.freezeTime) ) {
                        continue;
                    }
                }
            }
            if (bStruct.balance > amountLeftToSupport) {
                bStruct.balance = bStruct.balance.sub(amountLeftToSupport);
                amountLeftToSupport = 0;
                break;
            } else {
                amountLeftToSupport = amountLeftToSupport.sub(bStruct.balance);
                bStruct.balance = 0;
                nodesToRemove[removalIndex] = node;
                removalIndex++;
            }
        }
        for (uint256 j = 0; j < removalIndex; j++) {
            delete balanceStructures[_from][nodesToRemove[j]];
            bList.remove(nodesToRemove[j]);
        }
        if (amountLeftToSupport == 0) {
            return true;
        }
        return false;
    }
    
    function checkTransferPossibility (address _from, address _to, uint256 _value) internal returns (bool canTransfer) {
        
        if (_value > totalInternalSupply) { //unlikely to happen, but in this case this contract 
            //should be synced with external token by corresponding function.
            return false;
        }
        
        if (msg.sender == address(this)) {
            return true;
        } else {
            return findAndSubtractForTransfer(_from, _to, _value);
        }
        return false;
    }

    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(checkTransferPossibility(msg.sender, _to, _value)); //check that transfer is allowed by destination and not frozen
        
        if (msg.sender == address(this)) {
            return transferFromReserves(_to, _value, false);
        }
        
        if (_to != address(this)) {
            assert(BKXtoken.transfer(_to, _value));
            totalInternalSupply = totalInternalSupply.sub(_value);
            totalDistributed = totalDistributed.sub(_value);
        } else {
            totalDistributed = totalDistributed.sub(_value);
        }
        
        Transfer(msg.sender, _to, _value);
        return true;
    }
    
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        uint256 _allowance = allowed[_from][msg.sender];
        require(_allowance >= _value);
        require(checkTransferPossibility(_from, _to, _value));
        
        if (_from == address(this)) {
            return transferFromReserves(_to, _value, false);
        }
        
        allowed[_from][msg.sender] = _allowance.sub(_value);
        
        if (_to != address(this)) {
            assert(BKXtoken.transfer(_to, _value));
            totalInternalSupply = totalInternalSupply.sub(_value);
            totalDistributed = totalDistributed.sub(_value);
        } else {
            totalDistributed = totalDistributed.sub(_value);
        }
        
        Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));
        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) view public returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }

    function increaseApproval (address _spender, uint _addedValue) public
        returns (bool success) {
            allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
            Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
            return true;
    }

    function decreaseApproval (address _spender, uint _subtractedValue) public
        returns (bool success) {
            uint oldValue = allowed[msg.sender][_spender];
            if (_subtractedValue >= oldValue) {
            allowed[msg.sender][_spender] = 0;
            } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
            }
            Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
            return true;
    }

    function FrozenTokenHolder (address _BKXtoken) public {
        require(_BKXtoken != address(0));
        BKXtoken = ERC20(_BKXtoken);
        require(BKXtoken.decimals() == decimals);
    }

    function updateBalanceFromParent() public returns (bool success) { //owner can increase internal total supply
                                                                                // by synchronizing balance with external token contract
        uint256 newBalanceOnParent = BKXtoken.balanceOf(address(this));
        totalInternalSupply = newBalanceOnParent;
        assert(totalInternalSupply >= totalDistributed);
        return true;
    }


    function checkBalanceStructure(address _for, uint256 _index) 
        public 
        view 
        returns (uint256 bal, uint256 frAt, uint256 frTime, bool fr) {
        BalanceStructure storage balStr = balanceStructures[_for][_index];
        return (balStr.balance, balStr.fronzenAt, balStr.freezeTime, balStr.frozen);
    }

    function balanceStructureIndexes(address _for)
        public
        view
        returns (uint256[] indexes) {
            LibCLLu.CLL storage bList = balanceLists[_for];
            uint256 size = bList.sizeOf();
            uint256[] memory toReturn = new uint256[](size);
            uint256 node = 0;
            for (uint256 i = 0; i < size; i++) {
                node = bList.step(node, true);
                toReturn[i] = node;
            }
            return toReturn;
        }
        
    function transferFromReserves(address _to, uint256 _value, bool _unfrozen) internal returns (bool success) {
        require(_to != address(0));
        LibCLLu.CLL storage balanceList = balanceLists[_to];
        bool exists = balanceList.exists();
        uint256 newIndex = lastPushedIndexes[_to]+1;
        BalanceStructure memory structure = BalanceStructure({
            balance: _value,
            fronzenAt: now,
            freezeTime: defaultFreezeTime,
            frozen: (!_unfrozen)
        });
        balanceStructures[_to][newIndex] = structure;
        lastPushedIndexes[_to] = newIndex;
        if (!exists) {
            balanceList.push(newIndex, true);
        } else {
            uint256 lastNode = balanceList.step(0, false);
            balanceList.insert(lastNode, newIndex, true);
        }

        totalInternalSupply = totalInternalSupply.sub(_value);
        totalDistributed = totalDistributed.add(_value);
        Transfer(this, _to, _value);
        return true;
    }
    
    function purchaseFor(address _for, uint256 _value, bool _unfrozen) onlyOwner public returns (bool success) {
        require(transferFromReserves(_for, _value, _unfrozen));
        return true;
    }
    
    function setDestination(address _dest, bool _allowed) onlyOwner public returns (bool success) {
        allowedReceivers[_dest] = _allowed;
        return true;
    }
    
    function () external {
        assert(false);
    }
    
    function kill() onlyOwner public {
        uint256 totalBalance = BKXtoken.balanceOf(address(this));
        assert(BKXtoken.transfer(owner, totalBalance));
        selfdestruct(owner);
    }

}