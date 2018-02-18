pragma solidity ^0.4.19;

import './SafeMath.sol';
import './Ownable.sol';

contract Bork {
  using SafeMath for uint256;
  string public name;
  string public data_type;
  uint256 public totalSupply;
  int[] private data;
  address public creator;
  uint256 public price;
  address[] private approvalPool;
  address[] private declinePool;
  enum State { Pending, Approved, Rejected, Published }
  uint private state;
  address[] private committee;
  uint public created;

  mapping(address => uint256) public forSale;
  mapping(address => uint256) public balances;

  function Bork(address _creator, address[] _committee, uint256 _price, string _type, string _name, uint256 _totalSupply, int[] _data) public {
    name = _name;
    totalSupply = _totalSupply;
    data = _data;
    creator = _creator;
    data_type = _type;
    price = _price;
    state = uint(State.Pending);
    committee = _committee;
    created = now;

    if (_totalSupply < 5) revert(); // One for the approvers, one for the creator
  }

  function getCommitteeCount() external view returns (uint256) {
    return committee.length;
  }

  function getApprovalCount() external view returns (uint256) {
    return approvalPool.length;
  }

  function getDeclineCount() external view returns (uint256) {
    return declinePool.length;
  }

  function balanceOf(address _owner) external view returns (uint256 balance) {
      return balances[_owner];
  }

  function retrieveBorkData() external view returns (int[]) {
    if (balances[msg.sender] <= 0) revert();
    return data;
  }

  modifier onlyCommittee() {
    bool exists = false;
    for(uint i = 0; i < committee.length; i++) {
      if(msg.sender == committee[i]) exists = true;
    }

    require(exists);
    _;
  }

  function transferFrom(address _from, address _to, uint256 _value) private {
    if (_to == 0x0) revert();
    if (balances[_from] < _value) revert();
    if (balances[_to].add(_value) < balances[_to]) revert();
    if (state != uint(State.Published)) revert();
    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
  }

  function transfer(address _to, uint256 _value) external {
    transferFrom(msg.sender, _to, _value);
  }

  function buy(uint256 _amount, address _seller) external payable {
    if (msg.value != price) revert();
    if (_amount.mul(price) != msg.value) revert();
    if (state != uint(State.Published)) revert();

    if (balances[msg.sender].add(_amount) > totalSupply) revert();

    /* send the ether to the rich dude */
    _seller.transfer(msg.value);

    transferFrom(this, msg.sender, _amount);
    forSale[_seller] = forSale[_seller].sub(_amount);
  }

  function sell(uint256 _amount) external {
    if (balances[msg.sender] < _amount) revert();
    transferFrom(msg.sender, this, _amount);
    forSale[msg.sender] = forSale[msg.sender].add(_amount);
  }

  function cancelSale() external {
    if (forSale[msg.sender] <= 0) revert();
     transferFrom(this, msg.sender, forSale[msg.sender]);
    forSale[msg.sender] = 0;
  }

  function approve(address _approver) onlyCommittee external {
    if (hasAlreadyVoted(_approver, approvalPool)) revert();
    if (state != uint(State.Pending)) revert();
    approvalPool.push(_approver);

    if (approvalPool.length > committee.length/2) {
      state = uint(State.Approved);
    }
  }

  function decline(address _decliner) onlyCommittee external {
    if (hasAlreadyVoted(_decliner, declinePool)) revert();
    if (state != uint(State.Pending)) revert();

    declinePool.push(_decliner);

    if (declinePool.length > committee.length/2) {
      state = uint(State.Rejected);
    }
  }

  function hasAlreadyVoted(address _voter, address[] arr) private pure returns (bool) {
    for(uint i = 0; i < arr.length; i++) {
      if(_voter == arr[i]) return true;
    }

    return false;
  }

  function publish() external {
    if (creator != msg.sender) revert();
    if (state != uint(State.Approved)) revert();

    uint256 amountGiven;
    for(uint i = 0; i < approvalPool.length; i++) {
      amountGiven = amountGiven.add(1);
      if(approvalPool[i] == creator) balances[approvalPool[i]] = balances[approvalPool[i]].add(1);
    }

    amountGiven = amountGiven.add(1);
    balances[creator] = balances[creator].add(1);

    this.sell(totalSupply.sub(amountGiven));

    state = uint(State.Published);
  }

}

contract BorkCoin is Ownable {
  using SafeMath for uint256;

  string public name = "Bork Coin";
  string public symbol = "BORK";
  uint256 public decimals = 0;
  address[] public borks;

  enum State { Pending, Approved, Rejected, Published }

  uint private maximumBorks = 20;
  address[] private eliteBorkers;
  uint private maximumEliteBorkers = 5;

  function BorkCoin() public {
    eliteBorkers.push(msg.sender);
  }

  function getBorkCount() external view returns (uint256) {
    return borks.length;
  }

  function getEliteCount() external view returns (uint256) {
    return eliteBorkers.length;
  }

  function balanceOf(address _owner) external view returns (uint256 balance) {
      balance = 0;
      for(uint i = 0; i < borks.length; i++) {
        balance = balance.add(Bork(borks[i]).balanceOf(_owner));
      }
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
    if (eliteBorkers.length >= maximumEliteBorkers) revert();

    for(uint i = 0; i<eliteBorkers.length; i++) {
      if(_newGuy == eliteBorkers[i]) revert();
    }


    eliteBorkers.push(_newGuy);
  }

  function getEliteBorkerIndex(address _eliteBorker) private view returns (uint) {
    for(uint i = 0; i<eliteBorkers.length; i++) {
      if(_eliteBorker == eliteBorkers[i]) return i; // Returns index
    }

    return eliteBorkers.length; // Returns a number greater than max index
  }

  function removeEliteBorker(address _loser) public onlyOwner {
    if (eliteBorkers.length <= 0) revert();

    uint index = getEliteBorkerIndex(_loser);   // Get Index of EliteBorker
    if (index >= eliteBorkers.length) revert(); // Make sure we find someone

    eliteBorkers[index] = eliteBorkers[eliteBorkers.length-1];
    delete eliteBorkers[eliteBorkers.length - 1];
    eliteBorkers.length--;
  }

  function createBork(string _name, uint256 _price, string _type, uint256 _totalSupply, int[] _data) public onlyEliteBorker {
    // TODO: Check if name already exists???
    if (borks.length > maximumBorks) revert();
    address newBork = new Bork(msg.sender, eliteBorkers, _price, _type, _name, _totalSupply, _data);
    borks.push(newBork);
  }

  function isEliteBorker(address _address) public view returns (bool) {
    for(uint i = 0; i < eliteBorkers.length; i++) {
      if(_address == eliteBorkers[i]) return true;
    }

    return false;
  }

}
