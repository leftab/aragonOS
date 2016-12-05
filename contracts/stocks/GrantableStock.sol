pragma solidity ^0.4.6;

import "./Stock.sol";

contract GrantableStock is Stock {
  struct StockGrant {
    uint256 value;
    uint64 cliff;
    uint64 vesting;
    uint64 date;
  }

  mapping (address => mapping (uint256 => StockGrant)) grants;
  mapping (address => uint256) private grantsIndex;

  function grantStock(address _to, uint256 _value) onlyCompany {
    transfer(_to, _value);
  }

  function grantVestedStock(address _to, uint256 _value, uint64 _cliff, uint64 _vesting) onlyCompany {
    if (_cliff < now) throw;
    if (_vesting < now) throw;
    if (_cliff > _vesting) throw;

    grants[_to][grantsIndex[_to]] = StockGrant({date: uint64(now), value: _value, cliff: _cliff, vesting: _vesting});
    grantsIndex[_to] = safeAdd(grantsIndex[_to], 1);

    grantStock(_to, _value);
  }

  function vestedShares(StockGrant grant) private constant returns (uint256 vestedShares) {
    if (now < grant.cliff) return 0;
    if (now > grant.vesting) return grant.value;

    uint256 cliffShares = grant.value * uint256(grant.cliff - grant.date) / uint256(grant.vesting - grant.date);
    vestedShares = cliffShares;

    uint256 vestingShares = safeSub(grant.value, cliffShares);

    vestedShares = safeAdd(vestedShares, vestingShares * (now - uint256(grant.cliff)) / uint256(grant.vesting - grant.date));
  }

  function nonVestedShares(StockGrant grant) private constant returns (uint256) {
    return safeSub(grant.value, vestedShares(grant));
  }

  function transferrableShares(address holder) constant returns (uint256 nonVested) {
    uint256 grantIndex = grantsIndex[msg.sender];

    for (uint256 i = 0; i < grantIndex; i++) {
      nonVested = safeAdd(nonVested, nonVestedShares(grants[msg.sender][i]));
    }

    return safeSub(balances[holder], nonVested);
  }

  function transfer(address _to, uint _value) {
    if (msg.sender != company && _value > transferrableShares(msg.sender)) throw;

    super.transfer(_to, _value);
  }
}