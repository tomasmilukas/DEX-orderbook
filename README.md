# Decentralised exchange - order book model (WORK IN PROGRESS)

Dissclaimer: The logic of the smart contract is 80-90% finished and the front-end is 0% finished. That's why it's a WIP :).

After playing around with bots, I was interested in DEXes and AMMs, and I started off with building an order book model DEX (AMM clone from scratch is coming later)! This is a simple order book exchange with both market and limit orders available which introduce some unexpected complexity which will be explored down below.

Market order: is an order to buy or sell a security immediately. <br>
Limit order: is an order to buy or sell a security at a specific price. <br>

## Table of contents

* [Technologies](#technologies)
* [Setup & Logic](#setup)
* [Next steps](#next-steps)

## Technologies

The contracts were coded with **Solidity**. <br>
The front end will be coded with JavaScript by using the React library. <br>
The hosting will be done on XYZ. <br>
	
## Setup & Logic

The only contract within this project so far is **DEX3.sol**. We will be exploring the main logic behind the contract.

The unexpected complexity of having both limit & market orders is that if a market order swallows up all of the limit orders, it must then be held in a separate array, and then immediatelly filled up once a new limit order of the opposite side comes in. Moreover, when limit orders of either side are fully filled up, they both have to be deleted from their respective arrays.


## Next steps

The next steps are to fully finish the logic and then code up an elegant frontend. Once that is finished, I will try to clean up & simplify the code, while also exploring if anything else could be added to the exchange. Maybe I will code up an alternative frontend where it displays an AMM or a yield farming aggregator. It depends on what will inspire me at that moment :).
