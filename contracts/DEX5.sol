// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import './IERC20.sol';

contract DEX_5 {

    // Struct to define a Token data type 
    struct Token {
        bytes32 ticker;
        address token_address;
    }

    // Struct to define an Order data type 
    struct Order {
        bytes32 ticker;
        uint id;
        Listing listing;
        address trader;
        uint price;
        uint amount;
        uint filled; 
        uint date;
    }

    // Struct to define an Unfilled Market Order (MO = Market Order) data type
    struct Unfilled_MO {
        bytes32 ticker;
        uint id;
        Listing listing;
        address trader;
        uint amount;
        uint filled; 
        uint date;
    }

    // Enum that defines the direction of the listing (can only be BUY or SELL)
    enum Listing {
        BUY, 
        SELL
    }

    // Mappings and arrays
    mapping(bytes32 => Token) public tokens;
    bytes32[] public token_list;
    mapping(address => mapping(bytes32 => uint)) public trader_balance;
    mapping(bytes32 => mapping(uint => Order[])) public order_book;
    mapping(bytes32 => mapping(uint => Unfilled_MO[])) public unfilled_market_order;

    // Definitions
    uint public next_order_id;
    uint public next_trade_id;
    address public owner;
    bytes32 constant DAI = bytes32("DAI");

    event NewTrade(
        uint trade_id,
        uint order_id,
        bytes32 indexed ticker,
        address indexed trader1,
        address indexed trader2,
        uint amount,
        uint price,
        uint date
    );

    constructor() {
        owner = msg.sender;
    }

    // Modifier for only giving the owner the ability to call a function
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    // Modifier for stopping DAI trades (no use trading a stablecoin) 
    modifier tokenNotDai(bytes32 ticker){
    require(ticker != DAI, "Not allowed to trade DAI");
    _;
    }

    // Modifier for checking if the token exists when submitting an order
    modifier tokenExistance(bytes32 _ticker) {
        require(tokens[_ticker].token_address != address(0), "Such a token does not exist");
        _;
    }

    event Received(address sender, uint amount);

    receive() external payable {
    emit Received(msg.sender, msg.value);
    }

    // A function that will return the Limit Order array
    function fetchLimitOrders(
      bytes32 _ticker, 
      Listing listing) 
      external 
      view
      returns(Order[] memory) {
      return order_book[_ticker][uint(listing)];
    }

    // A function that will return the array of all the tokens on the exchange
    function fetchTokens() 
      external 
      view 
      returns(Token[] memory) {
      Token[] memory _tokens = new Token[](token_list.length);
      for (uint i = 0; i < token_list.length; i++) {
        _tokens[i] = Token(
          tokens[token_list[i]].ticker,
          tokens[token_list[i]].token_address
        );
      }
      return _tokens;
    }

    function addToken(
        bytes32 _ticker,
        address _token_address
    ) external onlyOwner {
        tokens[_ticker] = Token(_ticker, _token_address);
        token_list.push(_ticker);
    }

    function deposit(
        uint _amount,
        bytes32 _ticker
    ) tokenExistance(_ticker) external {
        IERC20 token = IERC20(tokens[_ticker].token_address);
        token.transferFrom(
            msg.sender,
            address(this),
            _amount
        );
        trader_balance[msg.sender][_ticker] += _amount;
    }

    function withdraw(
        uint _amount,
        bytes32 _ticker
    ) tokenExistance(_ticker) external {
        require(
            trader_balance[msg.sender][_ticker] >= _amount, "You are trying to withdraw more than you have"
            );
        IERC20 token = IERC20(tokens[_ticker].token_address);
        trader_balance[msg.sender][_ticker] -= _amount;
        token.transfer(
            msg.sender,
            _amount
        );
    }

    // Function that creates the limit order but does not execute it. It calls the execution function if rules pass.
    function createLimitOrder(
    bytes32 _ticker,
    uint _amount, 
    uint _price,
    Listing listing
    )
    tokenExistance(_ticker) 
    tokenNotDai(_ticker) 
    public {
        if (listing == Listing.SELL) {
            require(trader_balance[msg.sender][_ticker] >= _amount, "Trader balance too low");
        } else {
            require(trader_balance[msg.sender][DAI] >= _amount * _price, "DAI balance too low");
        }

    Order[] storage orders = order_book[_ticker][uint(listing)];

        orders.push(Order(
            _ticker,
            next_order_id,
            listing,
            msg.sender,
            _price,
            _amount,
            0,
            block.timestamp
        ));
    
    bubbleSort(_ticker, listing);
    next_order_id++;

    // Check if there is at least 1 order on the opposite side of the order book. If there aren't any orders on the opposite side, it means no execution is necessary.
    uint opposite_listing = uint(listing == Listing.SELL ? Listing.BUY: Listing.SELL);
    Order[] storage check_orders = order_book[_ticker][opposite_listing];
    Unfilled_MO[] storage unfilled_MO = unfilled_market_order[_ticker][opposite_listing];

    if (check_orders.length < 1 && unfilled_MO.length < 0){
    return;
    } 

    // Fetch the positions and prices of the orders that match the price in BOTH listings (necessary for updating both sides when orders are partially or fully filled)
    (bool found, uint position) = linearSearch(_ticker, opposite_listing, _price);
    (, uint position2) = linearSearch(_ticker, uint(listing), _price);

    // Execute ONLY if the priceResult is equivalent to the opposite listing. Binary search returns false for listings that don't match any price.
    if (found == true){
    executeLimitOrder(_ticker, _amount, _price, listing, position, position2);
    }

    // Check if any orders are in the unfulfilled market order array.
    if (unfilled_MO.length > 0) {
        fillUpMarketOrder(_ticker, _amount, _price, opposite_listing, position, listing);
    }
    }

 // Function that executes the limit order.
function executeLimitOrder(
    bytes32 _ticker,
    uint _amount, 
    uint _price,
    Listing listing,
    uint position,
    uint position2
    ) 
    tokenExistance(_ticker) 
    tokenNotDai(_ticker)
    private { 

    Order[] storage orders = order_book[_ticker][
        uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL)];
    Order[] storage orders_opposite = order_book[_ticker][uint(listing == Listing.SELL ? Listing.SELL : Listing.BUY)];  

    // Calculate if the order will be fully or partially filled. Get the matched variable to use for selling and buying operations.
    uint amount_available = orders[position].amount - orders[position].filled;

    uint matched = (_amount > amount_available) ? amount_available : _amount;

    // Update the filled section of the order for both sides
    orders[position].filled += matched;
    orders_opposite[position2].filled += matched;

    // emit event that a new trade is happening.
    emit NewTrade(
            next_trade_id,
            orders[position].id,
            _ticker,
            orders[position].trader,
            msg.sender,
            matched,
            orders[position].price,
            block.timestamp
            );

    // Execute the order via orderExchange function
    orderExchange(_ticker, _amount, orders[position].price, matched, position, listing);
    next_trade_id++;
    
    // Delete the order on the SELL / BUY side if they were fully filled.
    if (orders[position].filled == orders[position].amount){
        deleteLimitOrder(_price, _ticker, uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL));
    }
    if (orders_opposite[position2].filled == orders_opposite[position2].amount){
        deleteLimitOrder(_price, _ticker, uint(listing == Listing.SELL ? Listing.SELL : Listing.BUY));
    }
    
}

    // A function that allows to create a market order.
    function createMarketOrder(
        bytes32 _ticker,
        uint _amount,
        Listing listing
    ) 
    tokenExistance(_ticker) 
    tokenNotDai(_ticker) 
    external {
    if (listing == Listing.SELL) {
            require(trader_balance[msg.sender][_ticker] >= _amount, "Trader balance too low");
        }

    // Check if there is at least 1 order on the opposite side of the order book. No orders on the opposite side, means no execution necessary.
    uint opposite_listing = uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL);
    Order[] storage orders = order_book[_ticker][opposite_listing];

    if (orders.length < 1){
    return;
    } 

    // The loop will fulfill the match order fully from the available limit orders on the opposite side of the listing. Hence, if a BUY market order is created, it will go through the SELL limit orders until either the SELL array is empty or the market order is fully filled.
    uint j = 0;
    uint remainder_to_fill = _amount;

    while(orders.length > 0 && remainder_to_fill > 0) {
        uint amount_available = orders[0].amount - orders[0].filled;
        uint matched = (remainder_to_fill > amount_available) ? amount_available : remainder_to_fill;
        remainder_to_fill -= matched;
        orders[0].filled += matched;
        emit NewTrade(
            next_trade_id,
            orders[0].id,
            _ticker,
            orders[0].trader,
            msg.sender,
            matched,
            orders[0].price,
            block.timestamp    
        );

        // Call the order exchange function that will swap the assets between both parties.
        orderExchange(_ticker, _amount, orders[0].price, matched, 0, listing);

        // Delete the limit orders if they have been fully filled.
        if (orders[0].filled == orders[0].amount){
        deleteLimitOrder(orders[0].price, _ticker, uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL));
        }
        next_trade_id++;
        j++;
        }

    // In case the market order has not been fully filled (hence, the array of the opposite listing is empty), push the remainder into a separate array called unfilled_MO. This will be filled once a limit order is created.
    if (remainder_to_fill > 0) {
        Unfilled_MO[] storage unfilled_MO = unfilled_market_order[_ticker][uint(listing)];

        unfilled_MO.push(Unfilled_MO(
            _ticker,
            next_order_id,
            listing,
            msg.sender,
            remainder_to_fill,
            0,
            block.timestamp
        ));
    } 
    }

    // Function that fills up the unfilled market orders.
    function fillUpMarketOrder(
    bytes32 _ticker,
    uint _amount, 
    uint _price,
    uint opposite_listing,
    uint position,
    Listing listing
    ) private {
    
    Order[] storage orders = order_book[_ticker][uint(listing)];

    Unfilled_MO[] storage unfilled_MO = unfilled_market_order[_ticker][opposite_listing];

    uint remainder_to_fill = _amount;
    uint i = 0;
    
    // Equivalent function of the one in create market order with a few different details.
    while(unfilled_MO.length > 0 && remainder_to_fill > 0){
        uint amount_available = unfilled_MO[i].amount - unfilled_MO[i].filled;
        uint matched = (remainder_to_fill > amount_available) ? amount_available : remainder_to_fill;

        // Fills up the orders on both the limit array and the unfilled market order array
        remainder_to_fill -= matched;
        orders[position].filled += matched;
        unfilled_MO[i].filled += matched;
        
        emit NewTrade(
            next_trade_id,
            orders[position].id,
            _ticker,
            orders[position].trader,
            msg.sender,
            matched,
            orders[position].price,
            block.timestamp    
        );

        // Delete the unfilled market order if the total amount matches the filled amount 
        if (unfilled_MO[i].amount == unfilled_MO[i].filled){
        deleteUnfilledMarketOrders(_ticker, opposite_listing);
            }
        i++;
        next_trade_id++;
    }
    
    // Delete the order once it has been fulfilled fully.
    if (orders[position].filled == orders[position].amount){
        deleteLimitOrder(_price, _ticker, opposite_listing);
    }

    // If the limit order (the one used to fill up the market order) is not fully filled, call the create limit order function to push it into the appropriate array.
    if(remainder_to_fill > 0) {
        createLimitOrder(_ticker, remainder_to_fill, _price, listing);
    }
    }

// Swap the assets depending on the passed listing parameter.
    function orderExchange(
        bytes32 _ticker,
        uint _amount,
        uint price,
        uint matched,
        uint position,
        Listing listing
    ) public {
    Order[] storage orders = order_book[_ticker][uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL)];

    if(listing == Listing.SELL) {
            
            // ERC20 asset deducted, supplement balance with DAI (performing SELL operation for msg.sender)
            trader_balance[msg.sender][_ticker] -= matched;
            trader_balance[msg.sender][DAI] += matched * price;

            // Add ERC20 asset, and deduct balance with DAI (performing BUY operation for the other party)
            trader_balance[orders[position].trader][_ticker] += matched;
            trader_balance[orders[position].trader][DAI] -= matched * price;
        } else {

            // Require that msg.sender has enough balance in DAI to buy the trade at the desired quantity.
            require(trader_balance[msg.sender][DAI] >= _amount * price, "dai balance too low");

            // Add ERC20 asset, and deduct balance with DAI (performing BUY operation for msg.sender)
            trader_balance[msg.sender][DAI] -= matched * price;
            trader_balance[msg.sender][_ticker] += matched;

            // Deduct ERC20 asset, and add balance with DAI (performing SELL operation for the other party)
            trader_balance[orders[position].trader][_ticker] -= matched;
            trader_balance[orders[position].trader][DAI] += matched * price;
        }
    }

    // A function to delete limit orders once its called.
    function deleteLimitOrder(
        uint _priceResult,
        bytes32 _ticker,
        uint listing
        ) private {
        Order[] storage order_deletion = order_book[_ticker][listing];

        (,uint position_delete) = linearSearch(_ticker, listing, _priceResult);

        order_deletion[position_delete] = order_deletion[order_deletion.length - 1];
        order_deletion.pop();
    }


    // A function to delete market orders once its called.
    function deleteMarketOrders(
        bytes32 _ticker,
        uint listing
    ) private {
        Order[] storage orders = order_book[_ticker][listing];
        uint j = 0;
        while(j < orders.length){
            if (orders[j].filled == orders[j].amount){
                orders[j] = orders[orders.length - 1];
                orders.pop();
            }
            j++;
        }
    }

    // A function to delete unfilled market orders once its called.
    function deleteUnfilledMarketOrders(
        bytes32 _ticker,
        uint listing
    ) private {
        Unfilled_MO[] storage unfilled_MO = unfilled_market_order[_ticker][listing];
        uint j = 0;
        while(j < unfilled_MO.length){
            if (unfilled_MO[j].filled == unfilled_MO[j].amount) {
            unfilled_MO[j] = unfilled_MO[unfilled_MO.length - 1];
            unfilled_MO.pop();
            }
            j++;
        }
    }

    // A function that performs linear search to find if the limit order price fits.
    function linearSearch(
        bytes32 _ticker,
        uint listing,
        uint _price
        ) public view returns (bool found, uint position) {
        Order[] storage orders = order_book[_ticker][listing];
        uint i;
        for (i = 0; i < orders.length; i++) {
            if (orders[i].price == _price) {
            return(true, i);
            }
        }
        return(false, 0);
    }

    // Perform bubble sort operation to order the array.
    function bubbleSort(bytes32 _ticker, Listing listing) private {
        Order[] storage orders = order_book[_ticker][uint(listing)];        
        uint i = orders.length - 1;

        while(i > 0) {
        if(listing == Listing.BUY && orders[i - 1].price > orders[i].price){
            break;
        }
        if(listing == Listing.SELL && orders[i - 1].price < orders[i].price){
            break;
        }

        Order memory order = orders[i - 1];
        orders[i-1] = orders[i];
        orders[i] = order;
        i--;
        }
    }
  }
