import "../contracts/BorkCoin.sol";
import "truffle/Assert.sol";
import "truffle/DeployedAddresses.sol";

contract TestBorkCoin {

  function testInitialization() public {
    BorkCoin borkCoin = BorkCoin(DeployedAddresses.BorkCoin());

    uint expected = 10000;

    Assert.equal(borkCoin.eliteBorkers[0], expected, "Creator should be elite");
  }

}
