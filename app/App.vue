<template>
  <div id="app" v-loading="isLoadingMaskShow">
    <el-row :gutter="24">
      <el-col :span="20" :offset="2">
        <h1>Decentralized Skill Certificate</h1>
      </el-col>
    </el-row>
    <el-row :gutter="24">
      <el-col :span="10" :offset="2">
        <h4>Connected to: <small class="text-muted">{{ networkName }}</small></h4>
      </el-col>
    </el-row>
    <el-row :gutter="24">
      <el-col :span="10" :offset="2">
        <h4>Contract Address: <small class="text-muted">{{ contractAddress }}</small></h4>
      </el-col>
    </el-row>
    <el-row :gutter="24">
      <el-col :span="10" :offset="2">
        <h4>Gas Price: <small class="text-muted">{{ gasPrice }} ETH</small></h4>
      </el-col>
    </el-row>
    <el-row :gutter="24">
      <el-col :span="10" :offset="2">
        <h4>Ethereum Account: <small class="text-muted">{{ account }}</small></h4>
      </el-col>
    </el-row>

    <el-row :gutter="24" class="main-form">
      <el-col :span="14" :offset="2">
        <el-form ref="certificateForm" :model="certificateForm" label-width="150px" :label-position="'left'" @submit.native.prevent>
          <el-form-item label="Certificate ID">
            <el-input v-model="certificateForm.certificateName" :disabled="isCertificateLoaded"></el-input>
          </el-form-item>
          <el-form-item label="Certificate Content">
            <el-input type="textarea" v-model="certificateForm.certificateContent" :rows="10"></el-input>
          </el-form-item>
          <el-form-item label="Private Key">
            <el-input type="textarea" v-model="privateKey" :rows="5"></el-input>
          </el-form-item>
          <el-form-item>
            <el-switch v-model="isKeySavedLocally" active-text="Remember in browser" :disabled="localStorageNotAvailable" @change="savePrivateKeyToStorage"></el-switch>
            <el-button size="small" type="danger" style='float:right;'  @click="generatePrivateKey" plain>Generate Private Key</el-button>
          </el-form-item>
          <el-form-item>
            <el-alert title="" type="error" :closable="false" class="text-alert">
              Private Key is used to encrypt &amp; decrypt your certificates. Please backup locally and safely. If lost, no one is able to restore your certificates.
            </el-alert>
          </el-form-item>
          <el-form-item>
            <el-button size="medium" type="primary" @click="saveCertificate" round>Save Certificate</el-button>
            <el-button size="medium" @click="newCertificate" v-if="isCertificateLoaded" round >New Certificate</el-button>
          </el-form-item>
        </el-form>
      </el-col>
      <el-col :span="6">
        <h3> Your Certificates </h3>
        <ul>
          <li v-for="(certificate) of certificateAccount.certificates" :key="certificate.keyHash" @click="openSavedCertificate(certificate.keyHash)">{{ certificate.keyName }}</li>
        </ul>
      </el-col>
    </el-row>
    <el-dialog
      title="Dangerous"
      :visible.sync="dialogVisible"
      width="30%">
      <span>Your private key will be regenerated!<br/>Backup the old one if needed.</span>
      <span slot="footer" class="dialog-footer">
        <el-button size="small" type="danger" @click="dialogVisible = false" plain>Stooop!</el-button>
        <el-button size="small" type="success" @click="confirmGeneratePrivateKey" plain>Proceed</el-button>
      </span>
    </el-dialog>
  </div>
</template>

<script>
import Vue from 'vue';
import { Row, Col, Message, Form, FormItem, Input, Button, Switch, Dialog, Loading, Alert } from 'element-ui';
import 'element-ui/lib/theme-chalk/index.css'

// TODO
// Importing this cause getting ipfs content empty.
// Don't know why.  Use MetaMask injected instead.
// import Web3 from 'web3';
import Base58 from 'base-58';
import { Buffer } from 'buffer';
import IpfsApi from 'ipfs-api';
import { JSEncrypt } from 'jsencrypt';

Vue.use(Row);
Vue.use(Col);
Vue.use(Alert);
Vue.use(Form);
Vue.use(FormItem);
Vue.use(Input);
Vue.use(Button);
Vue.use(Switch);
Vue.use(Dialog);
Vue.use(Loading);

let web3js = null;
let ipfs = null;
let storage = null;
let skillCertificateInstance = null;
let certificateUpdatedEvent = null;

// Ropsten test network
const CONTRACT_ADDRESS = '0x242f7fa829fd9d609298434ddbb0be04026f6ad9';
const CONTRACT_CREATION_BLOCK = 3720017;

// Taken from Shmigers's answer in
// https://www.reddit.com/r/ethdev/comments/6lbmhy/a_practical_guide_to_cheap_ipfs_hash_storage_in/
function fromIPFSHash(hash) {
  const bytes = Base58.decode(hash);
  const multiHashId = 2;
  // remove the multihash hash id
  return bytes.slice(multiHashId, bytes.length);
};

function toIPFSHash(str) {
    // remove leading 0x
    const remove0x = str.slice(2, str.length);
    // add back the multihash id
    const bytes = Buffer.from(`1220${remove0x}`, "hex");
    const hash = Base58.encode(bytes);
    return hash;
};

export default {
  name: 'app',
  data () {
    return {
      networkName: 'unknown',
      gasPrice: 0,
      contractAddress: CONTRACT_ADDRESS,
      isNetworkReady: false,
      isLoadingMaskShow: false,
      dialogVisible: false,
      account: null,
      certificateAccount: {
        latestCertificateBlockNumber: CONTRACT_CREATION_BLOCK,
        certificates: []
      },
      isCertificateLoaded: false,
      localStorageNotAvailable: false,
      isKeySavedLocally: true,
      privateKey: '',
      certificateForm: {
        certificateName: '',
        certificateContent: ''
      }
    }
  },
  created() {
    if (typeof web3 !== 'undefined') {
      // Use MetaMask's provider
      web3js = new Web3(web3.currentProvider);
    } else {
      this.showAlertMsg('Please install <a href="https://metamask.io/" target="__blank">MetaMask</a> extension for your browser before using.', 'warning', 0);
      return;
    }

    this.initStorage();
    this.initContract();
    this.initIPFS();

    // Async
    this.detectNetwork();
    this.getGasPrice();
    this.initAccount();
  },
  methods: {
    detectNetwork() {
      const that = this;
      web3js.version.getNetwork((err, netId) => {
        that.isNetworkReady = true;

        switch (netId) {
          case "1":
            that.networkName = 'mainnet';
            break;
          case "2":
            that.networkName = 'deprecated Morden test network';
            break;
          case "3":
            that.networkName = 'Ropsten test network';
            break;
          case "4":
            that.networkName = 'Rinkeby test network';
            break;
          case "42":
            that.networkName = 'Kovan test network';
            break;
          default:
            that.isNetworkReady = false;
            break;
        }
      });
    },
    initStorage() {
      function noop() {};

      storage = {
        getItem: noop,
        setItem: noop,
        removeItem: noop
      };

      try {
        storage = window.localStorage;
      } catch (e) {
        this.localStorageNotAvailable = true;
        this.isKeySavedLocally = false;
      }
    },
    initContract() {
      var abiArray = [{"inputs":[],"payable":false,"stateMutability":"nonpayable","type":"constructor"},{"payable":true,"stateMutability":"payable","type":"fallback"},{"anonymous":false,"inputs":[{"indexed":true,"name":"_sender","type":"address"},{"indexed":true,"name":"_certificateKey","type":"bytes32"},{"indexed":false,"name":"_success","type":"bool"}],"name":"SkillCertificateUpdated","type":"event"},{"constant":true,"inputs":[{"name":"_user","type":"address"}],"name":"userExisted","outputs":[{"name":"","type":"bool"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_to","type":"address"},{"name":"_amount","type":"uint256"}],"name":"withdraw","outputs":[],"payable":false,"stateMutability":"nonpayable","type":"function"},{"constant":true,"inputs":[],"name":"getUserCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getUserAddress","outputs":[{"name":"","type":"address"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_certificateKey","type":"bytes32"}],"name":"getCertificate","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[],"name":"getCertificateKeysCount","outputs":[{"name":"","type":"uint256"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":true,"inputs":[{"name":"_index","type":"uint256"}],"name":"getCertificateKeyByIndex","outputs":[{"name":"","type":"bytes32"}],"payable":false,"stateMutability":"view","type":"function"},{"constant":false,"inputs":[{"name":"_certificateKey","type":"bytes32"},{"name":"_certificateContent","type":"bytes32"}],"name":"setCertificate","outputs":[],"payable":true,"stateMutability":"payable","type":"function"}];

      var SkillCertificate = web3js.eth.contract(abiArray);
      skillCertificateInstance = SkillCertificate.at(CONTRACT_ADDRESS);
    },
    initIPFS() {
      ipfs = IpfsApi('ipfs.infura.io', '5001', { protocol: 'https' });
    },
    getGasPrice() {
      const that = this;
      web3js.eth.getGasPrice(function(err, priceInWei) {
        that.gasPrice = web3js.fromWei(priceInWei, 'ether').toString(10);
      })
    },
    initAccount() {
      function _getAccount() {
        const that = this;

        web3js.eth.getAccounts(function(err, result) {
          if (err) {
            return;
          }

          if (result.length === 0 || result[0] === that.account) {
            return;
          }

          that.account = result[0];

          that.loadPreviousSavedCertificates();

          var pk = storage.getItem('pk');
          if (pk) {
            that.privateKey = pk;
            that.isKeySavedLocally = true;
          }
        });
      }

      setInterval(_getAccount.bind(this), 100);
    },
    loadPreviousSavedCertificates() {
      const certificateAccount = storage.getItem('account:' + this.account);

      if (certificateAccount) {
        this.certificateAccount = JSON.parse(certificateAccount);
      }

      this.loadCertificatesFromContractEventAndWatch();
    },
    loadCertificatesFromContractEventAndWatch() {
      if (certificateUpdatedEvent) {
        certificateUpdatedEvent.stopWatching();
      }

      certificateUpdatedEvent = skillCertificateInstance.SkillCertificateUpdated(
        { _sender: this.account },
        { fromBlock: this.certificateAccount.latestCertificateBlockNumber + 1, toBlock: 'latest' });

      const that = this;

      certificateUpdatedEvent.get(function(err, result) {
        var newCertificates = result.filter(function(log) {
          return log.args._success;
        });

        if (newCertificates.length === 0) {
          // No new certificate since last check
          that.updateCertificateToStorage();
          certificateUpdatedEvent.watch(that.addNewCertificateFromLog.bind(that));
          return;
        }

        that.certificateAccount.latestCertificateBlockNumber = newCertificates[newCertificates.length - 1].blockNumber;

        newCertificates = newCertificates.map(function(log) {
          return {
            keyHash: log.args._certificateKey,
            keyName: web3js.toAscii(log.args._certificateKey)
          }
        });

        that.addNewCertificates(newCertificates);

        that.updateCertificateToStorage();

        certificateUpdatedEvent.watch(that.addNewCertificateFromLog.bind(that));
      });
    },
    updateCertificateToStorage() {
      storage.setItem('account:' + this.account, JSON.stringify(this.certificateAccount));
    },
    addNewCertificates(newCertificates) {
      const that = this;

      newCertificates.forEach(function(newCertificate) {
        var index = that.certificateAccount.certificates.findIndex(function(certificate) {
          return certificate.keyHash === newCertificate.keyHash;
        })

        if (index === -1) {
          that.certificateAccount.certificates.splice(0, 0, newCertificate); // Add to the beginning
        }
      });
    },
    addNewCertificateFromLog(err, log) {
      var newCertificate = {
        keyHash: log.args._certificateKey,
        keyName: web3js.toAscii(log.args._certificateKey)
      };

      this.addNewCertificates([newCertificate]);
    },
    saveCertificate() {
      if (!this.account || !this.isNetworkReady) {
        this.showAlertMsg('Please check MetaMask network and account.');
        return false;
      }

      const that = this;
      const privateKey = this.privateKey;
      const certificateName = this.certificateForm.certificateName;
      const certificateContent = this.certificateForm.certificateContent;

      if (!certificateName || !certificateContent || !privateKey) {
        this.showAlertMsg('Missing Certificate Name, Certificate Content or Private Key.');
        return false;
      }

      const encryptApi = new JSEncrypt();
      encryptApi.setPrivateKey(privateKey);

      ipfs.files.add(new Buffer(encryptApi.encrypt(certificateContent)), function(err, res) {
        const ipfsFile = res[0];

        const nameHash = web3js.toHex(certificateName);

        const newHash = '0x' + new Buffer(fromIPFSHash(ipfsFile.hash)).toString('hex');

        skillCertificateInstance.setCertificate(nameHash, newHash, function (err, txHash) {
          if (err) {
            that.showAlertMsg('Failed.  Please check trx or try again later.', 'error');
            return;
          }

          that.showAlertMsg('Trx submiteed successfully.  Once confirmed, certificate will be listed.', 'success');
          that.isCertificateLoaded = true;
        });
      });

      return false;
    },
    newCertificate() {
      this.certificateForm.certificateName = '';
      this.certificateForm.certificateContent = '';
      this.isCertificateLoaded = false;
    },
    openSavedCertificate(keyHash) {
      this.showLoadingMask(true);

      const that = this;

      skillCertificateInstance.getCertificate(keyHash, function(err, certificateContent) {
        if (err) {
          that.showLoadingMask(false);
          console.log(err);
          that.showAlertMsg('Failed to load certificate.  Please try again later', 'error');
          return;
        }

        if (!certificateContent) {
          that.showLoadingMask(false);
          return;
        }

        if (!that.privateKey) {
          that.showLoadingMask(false);
          that.certificateForm.certificateName = web3js.toAscii(keyHash);
          that.certificateForm.certificateContent = certificateContent;
          that.isCertificateLoaded = true;
          return;
        }

        var encryptApi = new JSEncrypt();
        encryptApi.setPrivateKey(that.privateKey);

        var ipfsHash = toIPFSHash(certificateContent);

        ipfs.files.cat(ipfsHash, function(err, file) {
          that.showLoadingMask(false);
          if (err) {
            console.log(err);
            that.showAlertMsg('Failed to load certificate.  Please try again later', 'error');
            return;
          }

          that.certificateForm.certificateName = web3js.toAscii(keyHash);
          that.certificateForm.certificateContent = encryptApi.decrypt(file.toString());
          that.isCertificateLoaded = true;
        });
      });
    },
    showLoadingMask(isShow) {
      this.isLoadingMaskShow = isShow;
    },
    showAlertMsg(alertMsg, alertType = 'warning', duration = 3500) {
      this.$notify({
        title: '',
        dangerouslyUseHTMLString: true,
        message: alertMsg,
        type: alertType,
        showClose: true,
        center: true,
        duration
      });
    },
    generatePrivateKey() {
      this.dialogVisible = true;
    },
    savePrivateKeyToStorage() {
      if (this.isKeySavedLocally) {
        storage.setItem('pk', this.privateKey);
      } else {
        storage.removeItem('pk');
      }
    },
    confirmGeneratePrivateKey() {
      var encryptApi = new JSEncrypt();

      this.privateKey = encryptApi.getPrivateKey();
      this.savePrivateKeyToStorage();

      this.dialogVisible = false;
    }
  }
}
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  margin-top: 20px;
}

h1, h2, h3, h4, h5, h6 {
  margin-top: 0;
  margin-bottom: 0.5rem;
  font-family: inherit;
  font-weight: 500;
  line-height: 1.2;
  color: inherit;
}

ul {
  display: -webkit-box;
  display: -ms-flexbox;
  display: flex;
  -webkit-box-orient: vertical;
  -webkit-box-direction: normal;
  -ms-flex-direction: column;
  flex-direction: column;
  padding-left: 0;
  margin-top: 0;
  margin-bottom: 0;
}

li:first-child {
  border-top-left-radius: .25rem;
  border-top-right-radius: .25rem;
}

li {
  position: relative;
  display: block;
  padding: .75rem 1.25rem;
  margin-bottom: -1px;
  background-color: #fff;
  border: 1px solid rgba(0,0,0,.125);
}

li:hover {
  cursor: pointer;
  background-color: #2C3E50;
  color: white;
  font-weight: bold;
}

p {
  margin: 0;
  font-size: 1.1rem;
  line-height: normal;
}

.text-muted {
  color: #6c757d!important;
}

.main-form {
  margin-top: 20px;
}

.text-alert {
  line-height: 20px;
}

code {
  color: #000;
  background-color: #f9fafc;
  padding: 0 4px;
  border: 1px solid #eaeefb;
  border-radius: 4px;
}
</style>
