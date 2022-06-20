pragma solidity ^0.4.24;


contract Rules_Contract {


    // FIELDS

   
    uint public m_required;
    uint public m_numOwners;
    
 
    uint[256] m_owners;
    uint constant c_maxOwners = 4;
    
    mapping(uint => uint) m_ownerIndex;
    
    mapping(bytes32 => PendingState) m_pending;
    bytes32[] m_pendingIndex;
    
    
    
    struct PendingState {
        uint yetNeeded;
        uint ownersDone;
        uint index;
    }


 
    event Confirmation(address owner, bytes32 operation);


     modifier onlyowner {
        if (isOwner(msg.sender))
            _;
    }
    
	
    modifier onlymanyowners(bytes32 _operation) {
        if (confirmAndCheck(_operation))
            _;
    }
    
    

    
    function Rules_Contract(address[] _owners, uint _required) {
        m_numOwners = _owners.length + 1;
        m_owners[1] = uint(msg.sender);
        m_ownerIndex[uint(msg.sender)] = 1;
        for (uint i = 0; i < _owners.length; ++i)
        {
            m_owners[2 + i] = uint(_owners[i]);
            m_ownerIndex[uint(_owners[i])] = 2 + i;
        }
        m_required = _required;
    }
    
  
    function isOwner(address _addr) returns (bool) {
        return m_ownerIndex[uint(_addr)] > 0;
    }
    
    function hasConfirmed(bytes32 operationHash, address _owner) constant returns (bool) {
        var pending = m_pending[operationHash];
        uint ownerIndex = m_ownerIndex[uint(_owner)];

      
        if (ownerIndex == 0) return false;

      
        uint ownerIndexBit = 2**ownerIndex;
        if (pending.ownersDone & ownerIndexBit == 0) {
            return false;
        } else {
            return true;
        }
    }
    


    function confirmAndCheck(bytes32 _operation) internal returns (bool) {
   
        uint ownerIndex = m_ownerIndex[uint(msg.sender)];
        
        if (ownerIndex == 0) return;

        var pending = m_pending[_operation];
        
        if (pending.yetNeeded == 0) {
           
            pending.yetNeeded = m_required;
            
            pending.ownersDone = 0;
            pending.index = m_pendingIndex.length++;
            m_pendingIndex[pending.index] = _operation;
        }
        
        uint ownerIndexBit = 2**ownerIndex;
        
        if (pending.ownersDone & ownerIndexBit == 0) {
            Confirmation(msg.sender, _operation);
           
            if (pending.yetNeeded <= 1) {
               
                delete m_pendingIndex[m_pending[_operation].index];
                delete m_pending[_operation];
                return true;
            }
            else
            {
                
                pending.yetNeeded--;
                pending.ownersDone |= ownerIndexBit;
            }
        }
    }

    function reorganizeOwners() private returns (bool) {
        uint free = 1;
        while (free < m_numOwners)
        {
            while (free < m_numOwners && m_owners[free] != 0) free++;
            while (m_numOwners > 1 && m_owners[m_numOwners] == 0) m_numOwners--;
            if (free < m_numOwners && m_owners[m_numOwners] != 0 && m_owners[free] == 0)
            {
                m_owners[free] = m_owners[m_numOwners];
                m_ownerIndex[m_owners[free]] = free;
                m_owners[m_numOwners] = 0;
            }
        }
    }
    
    function clearPending() internal {
        uint length = m_pendingIndex.length;
        for (uint i = 0; i < length; ++i)
            if (m_pendingIndex[i] != 0)
                delete m_pending[m_pendingIndex[i]];
        delete m_pendingIndex;
    }
        
}



contract Revoking_Doc_Contract is Rules_Contract {
   
   
      
    bytes32 public hash;
    string private revoke_data;
    
    mapping (bytes32 => Transaction) m_txs;
    
    
    
    struct Transaction {
        address from;
        string data;
    }
    
    
    
    event SingleTransact(address owner, string data);
    
    event MultiTransact(address owner, bytes32 operation, string data);
    
    event ConfirmationNeeded(bytes32 operation, address initiator, string data);
    
    
    
 
    function Revoking_Doc_Contract(address[] _owners, uint _required)
            Rules_Contract(_owners, _required) {
    }
    
   
    function revoke_doc(string _data) onlyowner returns (bytes32) {
        
        if (block.number != 0) {
            SingleTransact(msg.sender, _data);
            return 0;
        }
        
        
       
        hash = sha3(msg.data, block.number);
        if (!confirm_revocation(hash,_data) && m_txs[hash].from == 0) {
            m_txs[hash].from = msg.sender;
            m_txs[hash].data = _data;
            ConfirmationNeeded(hash, msg.sender, _data);
        }
        return hash;
        
    }
    
    
    function getRevokeData() view returns (string){
        return revoke_data;
    }
    

    function confirm_revocation(bytes32 _hash, string data_) onlymanyowners(_hash) returns (bool) {
        if (hash == _hash) {
            MultiTransact(msg.sender, _hash, m_txs[_hash].data);
            delete m_txs[_hash];
            revoke_data = data_;
            return true;
        }
        
    }
    
    
    function clearPending() internal {
        uint length = m_pendingIndex.length;
        for (uint i = 0; i < length; ++i)
            delete m_txs[m_pendingIndex[i]];
        super.clearPending();
    }


}