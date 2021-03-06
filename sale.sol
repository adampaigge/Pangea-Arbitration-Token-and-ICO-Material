pragma solidity ^0.4.0;

// Token used to send shares
contract token { function mintToken(address target, uint256 mintedAmount);  }

contract sale {
    struct order {
        uint amount;
        address buyer;
    }
    
    mapping (uint => order) orderBook;
    
    uint public highestPrice;
    uint public totalSold;
    
    uint public totalTokens;
    uint public tokensSetAside;
    
    uint public minAmount;
    uint public saleStarted;
    
    address public crowdseller;
    
    token public rewardToken;
    
    
    // Generates an ethernal sale
    function sale(uint _minAmount, address _seller, uint _tokens, uint _tokensSetAside, token _rewardToken) {
        minAmount = _minAmount;
        crowdseller = _seller;
        totalTokens = _tokens;
        tokensSetAside = _tokensSetAside;
        rewardToken = token(_rewardToken);
        saleStarted = now;
    }
    
    // adds a buy order. For simplicity's sake I have one order per price point.
    // This shouldn't be a problem as you can have a min token deposit per price point
    // and you can have very small price point differences
    function putOrder(uint price) payable {
        if (msg.value < minAmount) throw;
        // there can be only one order per price point
        // so it looks for a similar price point to add
        bool seekPrice = true;
        uint currPrice = price;
        while(seekPrice) {
            order o = orderBook[currPrice];
            if (o.amount == 0 || currPrice < price - 100) seekPrice = false;
            currPrice--;
        }
        // if still hasn't found, throw
        if (o.amount != 0) throw;
        // create a order
        orderBook[currPrice] = order({amount: msg.value/currPrice, buyer: msg.sender});
        if (currPrice > highestPrice) highestPrice = currPrice;
        
        executeSale();
    }
    
    // cancels an order
    function cancelOrder(uint price) {
        order o = orderBook[price];
        if (o.amount == 0 || o.buyer != msg.sender) throw;
        uint valueToSend = price*o.amount;
        orderBook[price] = order({amount: 0, buyer: 0});
        msg.sender.transfer(valueToSend);
    }
    
    // a curve that generates how many tokens per seconds should be generated
    function sellTargetByDate(uint targetTime) constant returns (uint sellTarget) {
        // get the amount of days elapsed
        uint nb_days = targetTime * 1 days;
       
        if (nb_days <= 31) { // First month, we sell 140e6 tokens a day
            return 140e6 * nb_days;
        } else if (nb_days <= (25 * 31)) { // Next 24 months, 14e6 a day (25 because we include the first month ;))
            return 14e6 * nb_days;
        } else { // Time elapsed, only sell unsold tokens
            return 14756000000; // 140e6 * 31 + 14e6 * 24 * 31
        }
    }
    
    // anyone can call this, and it's also called at every put order
    function executeSale() {
        uint valueToSend;
        uint targetSale = sellTargetByDate(now) - totalSold;
        uint currPrice = highestPrice;
        while(targetSale > 0) {
            // if it's about to run out of gas, stop it
            if (msg.gas < 1000) targetSale = 0;
            // loop throught the highest sale
            order o = orderBook[currPrice];
            if (o.amount <= targetSale) {
                valueToSend = o.amount * currPrice;
                targetSale -= o.amount;
                totalSold += o.amount;
                rewardToken.mintToken(o.buyer, o.amount);
                orderBook[currPrice] = order({amount: 0, buyer: 0});
                crowdseller.transfer(valueToSend);
            } else {
                valueToSend = targetSale * currPrice;
                totalSold += targetSale;
                orderBook[currPrice] = order({amount: o.amount - targetSale, buyer: o.buyer});
                rewardToken.mintToken(o.buyer, targetSale);
                targetSale = 0;
                crowdseller.transfer(valueToSend);
            }
            currPrice--;
        }
        highestPrice = currPrice;
    }
}
