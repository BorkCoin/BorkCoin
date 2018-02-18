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
  address[] private approvalPool;
  address[] private declinePool;
  enum State { Pending, Approved, Rejected, Published }
  uint private state;
  address private parentContract;
  uint public created;
  uint256 public startingPrice;

  mapping(address => uint256) public forSale;
  mapping(address => uint256) public pricePerCoin;
  mapping(address => uint256) public balances;

  function Bork(address _parentContract, address _creator, uint256 _pricePerCoin, string _type, string _name, uint256 _totalSupply, int[] _data) public {
    name = _name;
    totalSupply = _totalSupply;
    data = _data;
    creator = _creator;
    data_type = _type;
    startingPrice = _pricePerCoin;
    state = uint(State.Pending);
    created = now;
    parentContract = _parentContract;

    if (_totalSupply < 5) revert(); // One for the approvers, one for the creator
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
    if (state != uint(State.Published)) revert();
    if (_amount.mul(pricePerCoin[_seller]) != msg.value) revert();
    if (forSale[_seller] < _amount) revert();

    /* send the ether to the rich dude */
    _seller.transfer(msg.value);

    transferFrom(this, msg.sender, _amount);
    forSale[_seller] = forSale[_seller].sub(_amount);

    if (forSale[_seller] <= 0) {
      pricePerCoin[_seller] = 0;
    }
  }

  function sell(uint256 _amount, uint256 _price) external {
    if (balances[msg.sender] < _amount) revert();
    transferFrom(msg.sender, this, _amount);
    forSale[msg.sender] = forSale[msg.sender].add(_amount);
    pricePerCoin[msg.sender] = _price;
  }

  function cancelSale() external {
    if (forSale[msg.sender] <= 0) revert();
    transferFrom(this, msg.sender, forSale[msg.sender]);
    forSale[msg.sender] = 0;
    pricePerCoin[msg.sender] = 0;
  }

  function approve(address _approver) external {
    if (BorkCoin(parentContract).isEliteBorker(_approver) == false) revert();
    if (hasAlreadyVoted(_approver, approvalPool)) revert();
    if (state != uint(State.Pending)) revert();
    approvalPool.push(_approver);

    if (approvalPool.length > BorkCoin(parentContract).eliteBorkerCount().div(2)) {
      state = uint(State.Approved);
    }
  }

  function decline(address _decliner) external {
    if (BorkCoin(parentContract).isEliteBorker(_decliner) == false) revert();
    if (hasAlreadyVoted(_decliner, declinePool)) revert();
    if (state != uint(State.Pending)) revert();

    declinePool.push(_decliner);

    if (declinePool.length > BorkCoin(parentContract).eliteBorkerCount().div(2)) {
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

    this.sell(totalSupply.sub(amountGiven), startingPrice);

    state = uint(State.Published);
  }

}

contract BorkCoin is Ownable {
  using SafeMath for uint256;

  string public name = "Bork Coin";
  string public symbol = "BORK";
  uint256 public decimals = 0;
  address[] public borks;
  mapping(address => uint256) public borkIndex;

  enum State { Pending, Approved, Rejected, Published }

  uint public maximumBorks = 20;
  uint public eliteBorkerCount;
  mapping(address => uint256) public eliteBorkers; // Starts 0 if not elite. 1 if elite
  uint public maximumEliteBorkers = 5;

  function BorkCoin() public {
    eliteBorkers[msg.sender] = 1;
    eliteBorkerCount = 1;
  }

  function getBorkCount() external view returns (uint256) {
    return borks.length;
  }

  function balanceOf(address _owner) external view returns (uint256 balance) {
      balance = 0;
      for(uint i = 0; i < borks.length; i++) {
        balance = balance.add(Bork(borks[i]).balanceOf(_owner));
      }
  }

  function addEliteBorker(address _newGuy) public onlyOwner {
    if (eliteBorkerCount >= maximumEliteBorkers) revert();
    if (eliteBorkers[_newGuy] != 0) revert();

    eliteBorkers[_newGuy] = 1;
    eliteBorkerCount = eliteBorkerCount.add(1);
  }

  function removeEliteBorker(address _loser) public onlyOwner {
    if (eliteBorkerCount <= 0) revert();
    if (eliteBorkers[_loser] == 0) revert();

    eliteBorkers[_loser] = 0;
  }

  function createBork(string _name, uint256 _price, string _type, uint256 _totalSupply, int[] _data) public {
    // TODO: Check if name already exists???
    if (borks.length > maximumBorks) revert();
    address newBork = new Bork(this, msg.sender, _price, _type, _name, _totalSupply, _data);
    borks.push(newBork);
  }

  function isEliteBorker(address _address) public view returns (bool) {
    if(eliteBorkers[_address] == 1) return true;

    return false;
  }

}
