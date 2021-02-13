import React, { Component } from 'react';
import './App.css';
import Web3 from 'web3'
import Operator from '../abi/Operator.json'

import { Button, Card, Form, Input} from 'semantic-ui-react'

class App extends Component {


  async componentWillMount() {
    await this.loadWeb3()
    await this.loadBlockchainData()
  }

  async loadBlockchainData() {
    const web3 = window.web3

    const accounts = await web3.eth.getAccounts()
    this.setState({ account: accounts[0] })



    // Load Token
    const networkId =  await web3.eth.net.getId()


      const operator = new web3.eth.Contract(Operator.abi,"0xA391CE933dbdB66e6918965C06e157a25C923115")
      this.setState({ operator });


      window.alert('Token contract not deployed to detected network.')
    



    this.setState({ loading: false })
  }

  async loadWeb3() {
    if (window.ethereum) {
      window.web3 = new Web3(window.ethereum)
      await window.ethereum.enable()
    }
    else if (window.web3) {
      window.web3 = new Web3(window.web3.currentProvider)
    }
    else {
      window.alert('Non-Ethereum browser detected. You should consider trying MetaMask!')
    }
  }


  constructor(props) {
    super(props);

    this.state = {
      account: '',
      ethBalance: '0',
      tokenBalance: '0',
      loading: true,
      operator:{},
      amount:1,
      oldOtoken:"",
      rolloverAmount:1,
      rolloverStrike:1,
      rolloverExpiry:1  
    }
    this.handleChange = this.handleChange.bind(this);
    this.handlePolicySubmit = this.handlePolicySubmit.bind(this);
  }

  async handlePolicySubmit(event){
    event.preventDefault();
    this.state.operator.methods.openVaultAndDeposit(this.state.amount).send({from: this.state.account }).on('transactionHash', (hash) => {
      console.log(hash);
    })
  }


  async handlePolicySubmit1(event){
    event.preventDefault();
    this.state.operator.methods.rollover(this.state.oldOtoken,this.state.rolloverAmount,this.state.rolloverStrike,this.state.rolloverExpiry).send({from: this.state.account }).on('transactionHash', (hash) => {
      console.log(hash);
    })
  }

  handleChange(evt) {
    this.setState({ [evt.target.name]: evt.target.value });
  }

  handleChange1(evt) {
    this.setState({ [evt.target.name]: evt.target.value });
  }

  render() {
    return (
      <div>
        <nav className="navbar navbar-dark fixed-top bg-dark flex-md-nowrap p-0 shadow">
          <a
            className="navbar-brand col-sm-3 col-md-2 mr-0"
          
            target="_blank"
            rel="noopener noreferrer"
          >
   
          </a>
        </nav>
        <div className="container-fluid mt-5">
          <div className="row">
            <main role="main" className="col-lg-12 d-flex text-center">
              <div className="content mr-auto ml-auto">
                <a
                 
                  target="_blank"
                  rel="noopener noreferrer"
                >
                 
                </a>
              
                <Form>
                        <Form.Group widths='equal'>
                          <Form.Field
                            id='form-input-control-mobile'
                            control={Input}
                            label='oldOtoken'
                            placeholder='oldOtoken'
                            name="oldOtoken"
                            onChange={this.handleChange}
                          />
                          <Form.Field
                            id='form-input-control-address'
                            control={Input}
                            label='rolloverAmount'
                            placeholder='rolloverAmount'
                            name="rolloverAmount"
                            onChange={this.handleChange}
                          />      
                            <Form.Field
                            id='form-input-control-address'
                            control={Input}
                            label='rolloverStrike'
                            placeholder='rolloverStrike'
                            name="rolloverStrike"
                            onChange={this.handleChange}
                          />      
                            <Form.Field
                            id='form-input-control-address'
                            control={Input}
                            label='rolloverExpiry'
                            placeholder='rolloverExpiry'
                            name="rolloverExpiry"
                            onChange={this.handleChange}
                          />      
                        </Form.Group>
                      </Form>
                      <Button onClick={this.handlePolicySubmit} basic color='green'>
                        Rollover
                      </Button>
                      <Form>
                        <Form.Group widths='equal'>
                          <Form.Field
                            id='form-input-control-portReason'
                            control={Input}
                            label='amount'
                            placeholder='amount'
                            name="amount"
                            onChange={this.handleChange1}
                          />
                        </Form.Group>
                      </Form>
                      <Button onClick={this.handlePolicySubmit1} basic color='red' >
                        openVaultAndDeposit
                      </Button>


                <a
                  className="App-link"

                  target="_blank"
                  rel="noopener noreferrer"
                >
                 
                </a>
              </div>
            </main>
          </div>
        </div>
      </div>
    );
  }
}

export default App;
