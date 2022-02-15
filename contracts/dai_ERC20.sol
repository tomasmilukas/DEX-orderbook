// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.9.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DAI is ERC20 {
    address public admin;
    constructor() ERC20("MAKER DAI", "DAI"){
        _mint(msg.sender, 1000 * 10 ** 18);
        admin = msg.sender;
    }

    function mint(address to, uint amount) external {
        require(msg.sender == admin, 'only admin');
        _mint(to, amount);
    }
    
}