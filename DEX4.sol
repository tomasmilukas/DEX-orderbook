// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import './IERC20.sol';

contract DEX_4 {

    // Token data type defined with a ticker and its address
    struct Token {
        bytes32 ticker;
        address token_address;
    }

    // Order data type defined with necessary elements
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

    struct Unfilled_MarketOrder {
        bytes32 ticker;
        uint id;
        Listing listing;
        address trader;
        uint amount;
        uint filled; 
        uint date;
    }

    // Enum defined for the direction of the listing/order
    enum Listing {
        BUY, 
        SELL
    }

    // Mappings and definitions
    mapping(bytes32 => Token) public tokens;
    bytes32[] public token_list;
    mapping(address => mapping(bytes32 => uint)) public trader_balance;
    mapping(bytes32 => mapping(uint => Order[])) public order_book;
    mapping(bytes32 => mapping(uint => Unfilled_MarketOrder[])) public unfilled_marketorder_book;
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

    // Modifier for stopping for submitting DAI orders (no use trading a stablecoin) 
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

    function fetchOrders(
      bytes32 _ticker, 
      Listing listing) 
      external 
      view
      returns(Order[] memory) {
      return order_book[_ticker][uint(listing)];
    }

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
    ) onlyOwner external {
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

    // Check if there is at least 1 order on the opposite side of the order book. No orders on the opposite side, means no execution necessary.
    uint opposite_listing = uint(listing == Listing.SELL ? Listing.BUY: Listing.SELL);
    Order[] storage check_orders = order_book[_ticker][opposite_listing];

    if (check_orders.length < 1){
    return;
    } 

    // Fetch the positions and prices of the orders that match the price in BOTH listing (necessary for updating both sides when orders are partially/fully filled)
    (bool found, uint position) = linearSearch(_ticker, opposite_listing, _price);
    (, uint position2) = linearSearch(_ticker, uint(listing), _price);

    // Execute ONLY if the priceResult is equivalent to the opposite listing. Binary search returns 0 for listings that don't match any price.
    if (found == true){
    executeLimitOrder(_ticker, _amount, _price, listing, position, position2);
    }

    Unfilled_MarketOrder[] storage unfilled_market_orders = unfilled_marketorder_book[_ticker][opposite_listing];
    // Check if any orders are in the unfulfilled market order array
    if (unfilled_market_orders.length > 0) {
        fillUpMarketOrder(_ticker, _amount, _price, opposite_listing, position, listing);
    }

    // THE FUNCTION has to CONTINUE of some of the amount of the limit order is unfilled by the unfulfilled market order
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

    Order[] storage orders = order_book[_ticker][uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL)];
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
    orderExchange(_ticker, _amount, matched, position, listing);
    next_trade_id++;
    
    // Delete the order on BOTH/EITHER the SELL / BUY side once it has been fulfilled fully.
    if (orders[position].filled == orders[position].amount){
        deleteLimitOrder(_price, _ticker, uint(listing == Listing.SELL ? Listing.BUY : Listing.SELL));
    }
    if (orders_opposite[position2].filled == orders_opposite[position2].amount){
        deleteLimitOrder(_price, _ticker, uint(listing == Listing.SELL ? Listing.SELL : Listing.BUY));
    }
}

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

    uint j = 0;
    uint remainder_to_fill = _amount;

    while(j < orders.length && remainder_to_fill > 0) {
        uint amount_available = orders[j].amount - orders[j].filled;
        uint matched = (remainder_to_fill > amount_available) ? amount_available : remainder_to_fill;
        remainder_to_fill -= matched;
        orders[j].filled += matched;
        emit NewTrade(
            next_trade_id,
            orders[j].id,
            _ticker,
            orders[j].trader,
            msg.sender,
            matched,
            orders[j].price,
            block.timestamp    
        );
        orderExchange(_ticker, _amount, matched, j, listing);
        next_trade_id++;
        j++;
        }
           
    if (remainder_to_fill > 0) {
        Unfilled_MarketOrder[] storage unfulfilled_market_orders = unfilled_marketorder_book[_ticker][uint(listing)];

        unfulfilled_market_orders.push(Unfilled_MarketOrder(
            _ticker,
            next_order_id,
            listing,
            msg.sender,
            remainder_to_fill,
            0,
            block.timestamp
        ));
    } 
    deleteMarketOrders(_ticker, opposite_listing);
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
    Unfilled_MarketOrder[] storage unfilled_market_orders = unfilled_marketorder_book[_ticker][opposite_listing];

    uint remainder_to_fill = _amount;
    uint i = 0;
    
    while(unfilled_market_orders.length > 0 && remainder_to_fill > 0){
        uint amount_available = unfilled_market_orders[i].amount - unfilled_market_orders[i].filled;
        uint matched = (remainder_to_fill > amount_available) ? amount_available : remainder_to_fill;

        remainder_to_fill -= matched;
        orders[position].filled += matched;

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

        orderExchange(_ticker, _amount, matched, position, listing);

        // Delete the unfilled market order if it reached 0 
        if (unfilled_market_orders[i].amount == unfilled_market_orders[i].filled){
        deleteUnfilledMarketOrders(_ticker, opposite_listing);
            }
        i++;
        next_trade_id++;
    }
    
    // Delete the order on EITHER the SELL / BUY side once it has been fulfilled fully.
    if (orders[position].filled == orders[position].amount){
        deleteLimitOrder(_price, _ticker, opposite_listing);
    }

    if(remainder_to_fill > 0) {
        createLimitOrder(_ticker, remainder_to_fill, _price, listing);
    }
    }


    // Function that executes the orders for both parties.
    function orderExchange(
        bytes32 _ticker,
        uint _amount,
        uint matched,
        uint position,
        Listing listing
    ) private {
    Order[] storage orders = order_book[_ticker][uint(listing)];

    if(listing == Listing.SELL) {
            
            // ERC20 asset deducted above, and supplement balance with DAI (performing SELL operation for msg.sender)
            trader_balance[msg.sender][_ticker] -= matched;
            trader_balance[msg.sender][DAI] += matched * orders[position].price;

            // Add ERC20 asset, and deduct balance with DAI (performing BUY operation for the other party)
            trader_balance[orders[position].trader][_ticker] += matched;
            trader_balance[orders[position].trader][DAI] -= matched * orders[position].price;
        
    } 
    if (listing == Listing.BUY) {
            // Require that msg.sender has enough balance in DAI to buy the trade at the desired quantity.
            require(trader_balance[msg.sender][DAI] >= _amount * orders[position].price, "dai balance too low");
            
            // Add ERC20 asset, and deduct balance with DAI (performing BUY operation for msg.sender)
            trader_balance[msg.sender][DAI] -= matched * orders[position].price;
            trader_balance[msg.sender][_ticker] += matched;

            // Deduct ERC20 asset, and add balance with DAI (performing SELL operation for the other party)
            trader_balance[orders[position].trader][_ticker] -= matched;
            trader_balance[orders[position].trader][DAI] += matched * orders[position].price;
        }
}

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

    function deleteUnfilledMarketOrders(
        bytes32 _ticker,
        uint listing
    ) private {
        Unfilled_MarketOrder[] storage unfilled_marketorder = unfilled_marketorder_book[_ticker][listing];
        uint j = 0;
        while(j < unfilled_marketorder.length){
            if (unfilled_marketorder[j].filled == unfilled_marketorder[j].amount) {
            unfilled_marketorder[j] = unfilled_marketorder[unfilled_marketorder.length - 1];
            unfilled_marketorder.pop();
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

// PROBLEMS:
// 1. market order does not go through (listing 0) if it fills up 1 order. NOT THE SAME FOR LISTING 1 side.
// 2. cannot create limit order if the amount exceeds of the leftover fillupmarketorder on opposite listing.