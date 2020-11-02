const ENS = artifacts.require("./ENSRegistry");
const Registrar = artifacts.require("./BaseRegistrarImplementation");
const SOCIRegistrar = artifacts.require("./SOCIRegistrarController");
const ReverseRegistrar = artifacts.require("./ReverseRegistrar");
const PublicResolver = artifacts.require("./PublicResolver");
const TestRegistra = artifacts.require("./TestRegistrar");
const SociToken = artifacts.require("./SOCIToken.sol");
const LpPools = artifacts.require("./LpPools");
const ZeroDAOCFO = artifacts.require("./ZeroDAOCFO");

const utils = require('web3-utils');
const namehash = require('eth-ens-namehash');

const tld = "did";

module.exports = async function(deployer, network, accounts) {

  let ens;
  let resolver;
  let registrar;
  let soci;
  let zeroDAOCFO;
  let reverseRegistrar

  accounts = ['0x621dbbe5ebf13217ac69ceef787d79df0a22a916'];
  const priceArr = [ 0, 0, 0, 1e12, 1e11, 1e10, 1e9, 0 ]

  deployer.deploy(SociToken, 990000000000000)
    .then(function(sociInstance) {
      soci = sociInstance;
      return deployer.deploy(ZeroDAOCFO, soci.address, accounts[0], 2000143825, accounts[0]);
    })
    .then(function(zeroInstance) {
      zeroDAOCFO = zeroInstance;
      return deployer.deploy(LpPools, soci.address, priceArr);
    })
    .then(function(sociInstance) {
      return deployer.deploy(ENS);
    })
    .then(function(ensInstance) {
      ens = ensInstance;
      return deployer.deploy(PublicResolver, ens.address);
    })
    .then(async function(resolverInstance) {
      resolver = resolverInstance;
      return deployer.deploy(ReverseRegistrar, ens.address, resolver.address);
    })
    .then(function(reverseRegistrarInstance) {
      reverseRegistrar = reverseRegistrarInstance;
      return setupResolver(ens, resolver, accounts);
    })
    .then(function() {
      return deployer.deploy(TestRegistra, ens.address, namehash.hash('test'));
    })
    .then(function(testRegistrarInstance) {
      return setupTestTegistrar(ens, testRegistrarInstance, resolver, accounts)
    })
    .then(function() {
      return deployer.deploy(Registrar, ens.address, namehash.hash(tld));
    })
    .then(function(registrarInstance) {
      registrar = registrarInstance;
      return setupRegistrar(ens, registrar, accounts);
    })
    .then(function() {
      return deployer.deploy(
        SOCIRegistrar,
        registrar.address,
        soci.address,
        zeroDAOCFO.address,
        priceArr
      );
    })
    .then(function(sociRegistrarInstance) {
      return setController(ens, sociRegistrarInstance.address, resolver, registrar, accounts)
    })
    .then(function() {
      return setupReverseRegistrar(
        ens,
        resolver,
        reverseRegistrar,
        accounts
      );
    });
};

async function setController(ens, sociRegistrarAddress, resolver, registrar, accounts) {
  await resolver.setAuthorisation(namehash.hash(tld), accounts[0], true)
  // set permanentRegistrar
  await resolver.setInterface(
    namehash.hash(tld),
    '0x544af80d',
    sociRegistrarAddress
  )
  // set permanentRegistrarWithConfig
  await resolver.setInterface(
    namehash.hash(tld),
    '0x5d20333e',
    sociRegistrarAddress
  )
  await ens.setSubnodeOwner(
    "0x0000000000000000000000000000000000000000",
    utils.sha3(tld),
    registrar.address
  );
  await registrar.addController(sociRegistrarAddress)
}

async function setupResolver(ens, resolver, accounts) {

  const resolverNode = namehash.hash("resolver");
  const resolverLabel = utils.sha3("resolver");

  await ens.setSubnodeOwner(
    "0x0000000000000000000000000000000000000000",
    resolverLabel,
    accounts[0]
  );

  await ens.setSubnodeOwner(
    "0x0000000000000000000000000000000000000000",
    utils.sha3("reverse"),
    accounts[0]
  );

  await ens.setSubnodeOwner(
    namehash.hash("reverse"),
    utils.sha3("addr"),
    accounts[0]
  )

  await ens.setSubnodeOwner(
    "0x0000000000000000000000000000000000000000",
    utils.sha3(tld),
    accounts[0]
  );

  await ens.setSubnodeOwner(
    namehash.hash("did"),
    utils.sha3("resolver"),
    accounts[0]
  )

  await ens.setResolver(namehash.hash("resolver.did"), resolver.address)
  await ens.setResolver(namehash.hash(tld), resolver.address)
  await ens.setResolver("0x0000000000000000000000000000000000000000", resolver.address)
  await ens.setResolver(resolverNode, resolver.address)
  await ens.setResolver(namehash.hash("addr.reverse"), resolver.address)

  await resolver.setAddr(resolverNode, resolver.address)
  await resolver.setAddr(namehash.hash("resolver.did"), resolver.address)
}

async function setupTestTegistrar(ens, testRegistrar, resolver, accounts) {
  await ens.setSubnodeOwner('0x00000000000000000000000000000000', utils.sha3('test'), accounts[0])
  await ens.setResolver(namehash.hash("test"), resolver.address)
  await ens.setSubnodeOwner('0x00000000000000000000000000000000', utils.sha3("test"), testRegistrar.address)
}

async function setupRegistrar(ens, registrar, accounts) {
  await ens.setSubnodeOwner(
    "0x0000000000000000000000000000000000000000",
    utils.sha3(tld),
    accounts[0]
  );
}

async function setupReverseRegistrar(
  ens,
  resolver,
  reverseRegistrar,
  accounts
) {
  await ens.setSubnodeOwner(
    namehash.hash("reverse"),
    utils.sha3("addr"),
    reverseRegistrar.address
  )
}
