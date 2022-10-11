# Strong hand project

This project is done using hardhat framework.
The idea of the project is that user deposits ether, which shall be converted to weth and invested into Avve pools, to generate interest. Only owner is able to collect generate interest. If user wants to withdraw it;s investment, he must done that after lockTime, or he shall be fined for wanting to leave project before reedem time.
If fee is taken from user, then it shall be distributed to other participants in proportion to participants balances. <br/>
Currently this project was testing by forking goerli network inside hardhat. The contracts are deployed to goerli test network. <br/>

FeeStrategyV1 : https://goerli.etherscan.io/address/0xc41265e23182aE8a59c5acf0f7d12925638b3901#code <br/>
StrongHand: https://goerli.etherscan.io/address/0xBEe3024234C0ACBd2773bFA6073E4C88B7B12C34#code <br/>

To run the project do the next stuff:

```shell
 npm i
rename .env.example to .env
npx hardhat compile
npx hardhat test
npx hardhat run .\scripts\deploy.ts --network goerli (to deploy it on goerli test network) 
```
