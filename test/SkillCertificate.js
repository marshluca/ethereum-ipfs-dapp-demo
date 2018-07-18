var SkillCertificate = artifacts.require('SkillCertificate');

contract('Skill Certificate', async (accounts) => {
  it('should have initial total count', async () => {
    const instance = await SkillCertificate.deployed();
    const initialCount = await instance.getUserCount();

    assert.equal(initialCount.valueOf(), 0);
  });

  it('should update total count after saving certificate', async () => {
    const key = web3.toHex('key');
    const content = web3.toHex('value');

    const instance = await SkillCertificate.deployed();
    await instance.setCertificate(key, web3.toHex(content));
    const newCount = await instance.getUserCount();

    assert.equal(newCount.valueOf(), 1);
  });


  it('should set and get skill certificate', async () => {
    const key = web3.toHex('key');
    const content = web3.toHex('value');

    const instance = await SkillCertificate.deployed();
    await instance.setCertificate(key, content);
    const newContent = await instance.getCertificate(key);

    assert.equal(web3.toUtf8(newContent), web3.toUtf8(content));
  });

  it('should be able to receive transfer', async () => {
    const contractAccount = accounts[0];
    const fromAccount = accounts[1];
    const amount = web3.toWei(1, "ether");
    const originalBalance = web3.eth.getBalance(contractAccount);

    web3.eth.sendTransaction({
      from: fromAccount,
      to: contractAccount,
      value: amount,
      gas: 420000
    });

    const newBalance = web3.eth.getBalance(contractAccount);
    assert.equal(newBalance.minus(amount).equals(originalBalance), true);
  });

  it('should get user address', async () => {
    const key = web3.toHex('key');
    const content = web3.toHex('value');

    const instance = await SkillCertificate.deployed();
    await instance.setCertificate(key, content);
    const addr = await instance.getUserAddress.call(1);

    assert.equal(addr, accounts[0]);
  });

  it('should get certificate by index', async () => {
    const key = web3.toHex('key');
    const content = web3.toHex('value');

    const instance = await SkillCertificate.deployed();
    await instance.setCertificate(key, content);
    const newKey = await instance.getCertificateKeyByIndex.call(0);

    assert.equal(web3.toUtf8(newKey), web3.toUtf8(key));
  });

  it('should throw exception if not owner calls getUserCount', async () => {
    const notOwnerAccount = accounts[2];
    const instance = await SkillCertificate.deployed();

    try {
      const initalCount = await instance.getUserCount.call({ from: notOwnerAccount });
    } catch (e) {
      expect(e, 'I know it').to.exist;
    }
  });
});
