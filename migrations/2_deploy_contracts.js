var Ownable = artifacts.require("./Ownable.sol");
var SkillCertificate = artifacts.require('./SkillCertificate.sol');

module.exports = function(deployer) {
  deployer.deploy(Ownable);
  deployer.link(Ownable, SkillCertificate);
  deployer.deploy(SkillCertificate);
}
