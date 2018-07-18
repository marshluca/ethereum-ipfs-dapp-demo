pragma solidity ^0.4.23;

import "./Ownable.sol";

/**
 * @title Skill Certificate
 */
contract SkillCertificate is Ownable {
  struct UserInfo {
    mapping(bytes32 => bytes32) certificates;
    bytes32[] certificateKeys;
    uint256 index; // 1-based
  }

  mapping(address => UserInfo) private registerUsers;
  address[] private userIndex;

  event SkillCertificateUpdated(address indexed _sender, bytes32 indexed _certificateKey, bool _success);

  constructor() public {
  }

  function userExisted(address _user) public constant returns (bool) {
    if (userIndex.length == 0) {
      return false;
    }

    return (userIndex[registerUsers[_user].index - 1] == _user);
  }

  function () public payable {
  }

  /**
   * @dev for owner to withdraw ETH
   * @param _to The address where withdraw to
   * @param _amount The amount of ETH to withdraw
   */
  function withdraw(address _to, uint _amount) public onlyOwner {
    _to.transfer(_amount);
  }

  /**
   * @dev For owner to check registered user count
   */
  function getUserCount() public view onlyOwner returns (uint256) {
    return userIndex.length;
  }

  /**
   * @dev For owner to check registered user address based on index
   * @param _index Starting from 1
   */
  function getUserAddress(uint256 _index) public view onlyOwner returns (address) {
    require(_index > 0);
    return userIndex[_index - 1];
  }

  /**
   * @dev For user to get their own skill certificate
   * @param _certificateKey The key identifier for particular certificate
   */
  function getCertificate(bytes32 _certificateKey) public view returns (bytes32) {
    return registerUsers[msg.sender].certificates[_certificateKey];
  }

  /**
   * @dev For user to get their own skill certificate keys count
   */
  function getCertificateKeysCount() public view returns (uint256) {
    return registerUsers[msg.sender].certificateKeys.length;
  }

  /**
   * @dev For user to get their own skill certificate key by index
   * @param _index The 0-based index for particular certificate
   */
  function getCertificateKeyByIndex(uint256 _index) public view returns (bytes32) {
    return registerUsers[msg.sender].certificateKeys[_index];
  }

  /**
   * @dev For user to update their own skill certificate
   * @param _certificateKey The key identifier for particular certificate
   * @param _certificateContent The certificate path hash
   */
  function setCertificate(bytes32 _certificateKey, bytes32 _certificateContent) public payable {
    require(_certificateKey != "");
    require(_certificateContent != "");

    address userAddr = msg.sender;
    UserInfo storage user = registerUsers[userAddr];
    if (user.certificates[_certificateKey] == "") {
      user.certificateKeys.push(_certificateKey);
    }
    user.certificates[_certificateKey] = _certificateContent;

    if (user.index == 0) {
      userIndex.push(userAddr);
      user.index = userIndex.length;
    }
    emit SkillCertificateUpdated(userAddr, _certificateKey, true);
  }
}
