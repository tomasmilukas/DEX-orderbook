# Decentralised exchange - order book model (LOGIC ONLY)

Dissclaimer: Only the logic is finished of the contract, the frontend is a WIP.

After playing around with bots, I was interested in DEXes and AMMs, and I started off with building an order book model DEX (AMM clone from scratch is coming later)! This is a simple order book exchange with both market and limit orders available which introduce some unexpected complexity which will be explored down below.

Terminology:
Market order: is an order to buy or sell a security immediately. <br>
Limit order: is an order to buy or sell a security at a specific price. <br>

If you are curious about the the contract and want to interact with it, here are the relevant details: <br>
The DEX contract address: 0x2294e0214c180f91AeE7C371fa260BE8B0882a3d <br>
The polygonscan link to the contract: https://polygonscan.com/address/0x2294e0214c180f91AeE7C371fa260BE8B0882a3d <br>

## Table of contents

* [Technologies](#technologies)
* [Setup & Logic](#setup)
* [Next steps](#next-steps)

## Technologies

The contracts were coded with **Solidity**. <br>
The front end will be coded with JavaScript and JSX (using the React library). <br>
	
## Setup & Logic

The only relevant contract within the project is **DEX5.sol** as all the logic is contained there. There is an interface contract to handle basic ERC20 functions and the other files are there for running test cases.

Some of the unexpected complexity of handling both limit and market orders is to contain unfilled market orders for the next limit orders that might come in, and appropriately arranging the values within either the SELL or BUY listings for limit orders.

If you wish to interact with the contract, you should download the hardhat environment as the test cases are already specifically written for that environment. There is no reason to deploy it, as that is already done within the test file (sample-test.js). The deploy file is only for people who wish to fork it and deploy it on other chains or improve it and deploy it to mainnet.

Once the hardhat environment is installed, add the appropriate networks and private keys in the hardhat.config.js file, and simply run the test cases. The test cases covered the majority of the contracts complex functions.

## Next steps

The next step is to finish the front-end and optimise the code for gas efficiency.

s are to fully finish the logic and then code up an elegant frontend. Once that is finished, I will try to clean up & simplify the code, while also exploring if anything else could be added to the exchange. Maybe I will code up an alternative frontend where it displays an AMM or a yield farming aggregator. It depends on what will inspire me at that moment :).
