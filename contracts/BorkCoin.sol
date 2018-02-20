pragma solidity ^0.4.19;

import './SafeMath.sol';
import './Ownable.sol';

contract BorkData {
  int[] private data;

  function BorkData(int[] _data) {
    data = _data;
  }

  function download() external returns (int[]) {
    return data;
  }
}

contract Bork {
  using SafeMath for uint256;
  string public name;
  string public data_type;
  address public parentContract;
  address public dataContract;
  uint256 public startingPrice;
  uint256 public totalSupply;
  address public creator;
  uint public created;

  enum State { Pending, Approved, Rejected, Published }
  uint public state;

  mapping(address => uint256) public forSale;
  mapping(address => uint256) public pricePerCoin;
  mapping(address => uint256) public balances;

  mapping(address => uint) public approvalPool;
  address[] public approvers;
  uint public approvedVoteCount = 0;

  mapping(address => uint) public declinePool;
  uint public declinedVoteCount = 0;

  function Bork(address _parentContract, address _creator, uint256 _pricePerCoin, string _type, string _name, uint256 _totalSupply, address _dataContract) public {
    name = _name;
    totalSupply = _totalSupply;
    creator = _creator;
    data_type = _type;
    startingPrice = _pricePerCoin;
    state = uint(State.Pending);
    created = now;
    parentContract = _parentContract;
    dataContract = _dataContract;

    if (_totalSupply < 5) revert(); // One for the approvers, one for the creator
  }

  function balanceOf(address _owner) external view returns (uint256 balance) {
      return balances[_owner];
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
    if (state != uint(State.Pending)) revert();
    if (BorkCoin(parentContract).isEliteBorker(_approver) == false) revert();
    if (hasAlreadyVoted(_approver)) revert();
    approvalPool[_approver] = 1;
    approvedVoteCount = approvedVoteCount.add(1);
    approvers.push(_approver);

    if (approvedVoteCount > BorkCoin(parentContract).eliteBorkerCount().div(2)) {
      state = uint(State.Approved);
    }
  }

  function decline(address _decliner) external {
    if (state != uint(State.Pending)) revert();
    if (BorkCoin(parentContract).isEliteBorker(_decliner) == false) revert();
    if (hasAlreadyVoted(_decliner)) revert();
    declinePool[_decliner] = 1;
    declinedVoteCount = declinedVoteCount.add(1);

    if (declinedVoteCount > BorkCoin(parentContract).eliteBorkerCount().div(2)) {
      state = uint(State.Rejected);
    }
  }

  function hasAlreadyVoted(address _voter) private pure returns (bool) {
    if(approvalPool[_voter] == 1) return true;
    if(declinePool[_voter] == 1) return true;

    return false;
  }

  function publish() external {
    if (state != uint(State.Approved)) revert();
    if (creator != msg.sender) revert();

    uint256 amountGiven;
    for(uint i = 0; i < approvedVoteCount; i++) {
      amountGiven = amountGiven.add(1);
      if(approvers[i] == creator) balances[approvers[i]] = balances[approvers[i]].add(1);
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

  enum State { Pending, Approved, Rejected, Published }

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

  function addBork(address _bork) public {
    if (Bork(_bork).parentContract() != address(this)) revert();
    if (Bork(_bork).state() != uint(State.Published)) revert();
    borks.push(_bork);
  }

  function isEliteBorker(address _address) public view returns (bool) {
    if(eliteBorkers[_address] == 1) return true;

    return false;
  }

}
