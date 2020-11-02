import React, { Component } from 'react';
import Web3 from "web3";
class App extends Component {
  constructor(props) {
    super(props);
    this.state = {
      value:0
    };
  }
  async componentDidMount() {
    if (typeof window.ethereum !== 'undefined') {
      const ethereum = window.ethereum
      ethereum.autoRefreshOnNetworkChange = false

      try {
        const accounts = await ethereum.enable()
        console.log(accounts)
        const provider = window['ethereum']
        console.log(provider)
        console.log(provider.chainId)
        const web3 = new Web3(provider)
        console.log(web3)
        const abi = require("./contract.abi.json")
        const address = "0x621dbbe5ebf13217ac69ceef787d79df0a22a916"
        window.myContract = new web3.eth.Contract(abi.abi,address)
        console.log(window.myContract)
        window.defaultAccount = accounts[0].toLowerCase()
        console.log(window.defaultAccount)

        ethereum.on('accountsChanged', function (accounts) {
          console.log("accountsChanged:" + accounts)
        })
        ethereum.on('networkChanged', function (networkVersion) {
          console.log("networkChanged:" + networkVersion)
        })
      } catch (e) {

      }
    } else {
      console.log('no metamask')
    }
  }
  Getter = () => {
    window.myContract.methods.value().call().then(value=>{
      console.log(value)
      this.setState({value:value})
    })
  }
  Increase = () => {
    window.myContract.methods.increase(1).send({from:window.defaultAccount})
    .on('transactionHash',(transactionHash)=>{
      console.log('transactionHash',transactionHash)
    })
    .on('confirmation',(confirmationNumber,receipt)=>{
      console.log({ confirmationNumber: confirmationNumber, receipt: receipt })
    })
    .on('receipt',(receipt)=>{
      console.log({ receipt: receipt })
    })
    .on('error',(error,receipt)=>{
      console.log({ error: error, receipt: receipt })
    })
  }
  render() {
    return (
      <div>
        <div>{this.state.value}</div>
        <div>
          <button onClick={() => { this.Getter() }}>Getter</button>
        </div>
        <div>
          <button onClick={() => { this.Increase() }}>Increase</button>
        </div>
        <div></div>
      </div>
    );
  }
}

export default App;