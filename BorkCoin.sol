pragma solidity ^0.4.13;

import './SafeMath.sol';
import './Ownable.sol';

contract Bork {
  using SafeMath for uint256;
  string public name;
  uint256 public totalSupply;
  int[] private data;
  address public creator;

  mapping(address => uint256) balances;

  function Bork(address _creator, string _name, uint256 _totalSupply, int[] _data) {
    name = _name;
    totalSupply = _totalSupply;
    data = _data;
    creator = _creator;
    balances[_creator] = totalSupply;
  }

  function balanceOf(address _owner) external view returns (uint256 balance) {
      return balances[_owner];
  }

  function transfer(address _from, address _to, uint256 _value) external {
    if (_to == 0x0) revert();
    if (balances[_from] < _value) revert();
    if (balances[_to].add(_value) < balances[_to]) revert();
    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
  }

  function mint(address _to, uint256 _amount) external {
    if (_to == 0x0) revert();
    if (balances[_to].add(_amount) > totalSupply) revert();

    balances[_to] = balances[_to].add(_amount);
  }

}

contract BorkCoin is Ownable {
  using SafeMath for uint256;

  string public name;
  string public symbol;
  uint256 public decimals;
  address[] private borks;
  address[] private pendingBorks;
  mapping(address => address[]) public approvalPool;
  mapping(address => address[]) public declinePool;

  uint private maximumBorks;
  mapping(address => uint256) public balances;
  address[] private eliteBorkers;

  function BorkCoin() public {
    name = "Bork Coin";
    symbol = "BKC";
    decimals = 0;
    maximumBorks = 20;
    eliteBorkers.push(msg.sender);
  }

  modifier onlyEliteBorker() {
    bool exists = false;
    for(uint i = 0; i<eliteBorkers.length; i++) {
      if(msg.sender == eliteBorkers[i]) exists = true;
    }

    require(exists);
    _;
  }

  function addEliteBorker(address _newGuy) public onlyOwner {
    if (eliteBorkers.length >= 5) revert();

    eliteBorkers.push(_newGuy);
  }

  function getEliteBorkerIndex(address _eliteBorker) private view returns (uint) {
    for(uint i = 0; i<eliteBorkers.length; i++) {
      if(_eliteBorker == eliteBorkers[i]) return i; // Returns index
    }

    return eliteBorkers.length; // Returns a number greater than max index
  }

  function hasEliteBorkerVoted(address _eliteBorker, address[] arr) private view returns (bool) {
    for(uint i = 0; i<arr.length; i++) {
      if(_eliteBorker == arr[i]) return true;
    }

    return false;
  }

  function removeEliteBorker(address _loser) public onlyOwner {
    if (eliteBorkers.length <= 0) revert();

    uint index = getEliteBorkerIndex(_loser);   // Get Index of EliteBorker
    if (index >= eliteBorkers.length) revert(); // Make sure we find someone

    eliteBorkers[index] = eliteBorkers[eliteBorkers.length-1];
    delete eliteBorkers[eliteBorkers.length - 1];
    eliteBorkers.length--;
  }

  function createBork(string _name, uint256 _totalSupply, int[] _data) onlyEliteBorker {
    // TODO: Check if name already exists???
    if (borks.length > maximumBorks) revert();
    address newBork = new Bork(msg.sender, _name, _totalSupply, _data);
    pendingBorks.push(newBork);
  }

  function getPendingBorkIndex(address _pendingBork) private view returns (uint) {
    for(uint i = 0; i<pendingBorks.length; i++) {
      if(_pendingBork == pendingBorks[i]) return i; // Returns index
    }

    return pendingBorks.length; // Returns a number greater than max index
  }

  function approveBork(uint index) public onlyEliteBorker {
    if (borks.length > maximumBorks) revert();
    if (hasEliteBorkerVoted(msg.sender, approvalPool[pendingBorks[index]])) revert();
    approvalPool[pendingBorks[index]].push(msg.sender);

    if (approvalPool[pendingBorks[index]].length >= eliteBorkers.length/2) {
      borks.push(pendingBorks[index]);
      Bork bork = Bork(borks[borks.length - 1]);
      balances[bork.creator()] = balances[bork.creator()].add(bork.totalSupply());
      // Clear out the old pending stuff
      deletePendingBork(index);
    }

  }

  function declineBork(uint index) public onlyEliteBorker {
    if (pendingBorks.length <= 0) revert();
    if (hasEliteBorkerVoted(msg.sender, declinePool[pendingBorks[index]])) revert();
    declinePool[pendingBorks[index]].push(msg.sender);

    if (declinePool[pendingBorks[index]].length >= eliteBorkers.length/2) {
      // Clear out the old pending stuff
      deletePendingBork(index);
    }
  }

  function deletePendingBork(uint index) private {
    if (pendingBorks.length <= 0) revert();

    pendingBorks[index] = pendingBorks[pendingBorks.length-1];
    delete pendingBorks[pendingBorks.length - 1];
    pendingBorks.length--;

    for(uint i = 0; i<declinePool[pendingBorks[index]].length; i++) {
      delete declinePool[pendingBorks[index]][i];
    }
    for(uint j = 0; j<approvalPool[pendingBorks[index]].length; j++) {
      delete approvalPool[pendingBorks[index]][j];
    }
  }

  function transfer(address _bork, address _to, uint256 _value) public {
    if (_to == 0x0) revert();
    if (balances[msg.sender] < _value) revert();
    if (balances[_to].add(_value) < balances[_to]) revert();

    Bork(_bork).transfer(msg.sender, _to, _value);

    // Maybe we can get rid of the below and just loop through everything instead to get balance.
    balances[_to] = balances[_to].add(_value);
    balances[msg.sender] = balances[msg.sender].sub(_value);
  }

}
