pragma solidity = 0.8.0;
// SPDX-License-Identifier: MIT

contract TaxiBusiness {
    
    struct Participant{
        address payable p_address; //identify the Participant
        uint balance;
        bool proposedRepurchaseCarVote;
        bool proposedCarVote;
        bool proposedDriverVote;
    }
    
    struct TaxiDriver{
        address payable identity;
        uint salary;
        uint account;
    }
    
    struct ProposedCar{
        bytes32 carId;
        uint price;
        uint offerValidTime;
        uint approvalState;
        bool isProposed;
    }
    
    struct ProposedDriver{
        address payable proposedDriverIdentity;
        uint approvalState;
        uint salary;
        bool isProposed;
    }
    
    
    Participant[] participants; // to keep tract of the mapping's elements, a separate array is created
    mapping(address => Participant) public participantByAddress;
    mapping (address => bool) isJoined; //it is for determining whether a participant has already joined or not
    
    address manager;
    TaxiDriver public taxiDriver;
    address payable public carDealer;
    uint public contractBalance; // Current total money in the contract that has not been distributed
    uint FixedExpenses = 10 ether; //for every 6 months 
    uint participationFee = 100 ether; //amount that participants needs to pay for entering the taxi business
    bytes32 ownedCar; // identified with a 32 digit number, CarID
    uint releaseSalaryTime;
    uint payCarExpensesTime;
    uint payDividendTime;
    ProposedCar public proposedCar;
    ProposedCar public proposedRepurchase;
    ProposedDriver public proposedDriver;
   
    
    // Called by owner of the contract and sets the manager and other initial values for state variables
    constructor(){
        manager = msg.sender;
        contractBalance = 0;
        payCarExpensesTime = block.timestamp;
        payDividendTime = block.timestamp;
    }
    
    
    modifier onlyManager{
        require(
            msg.sender == manager,
            "Only Manager can call this function"
        );
        _; // if the statement above is true, then run the function body.
    }
    
    modifier onlyParticipant{
        require(
            msg.sender == participantByAddress[msg.sender].p_address,
            "Only Participants can call this function"
        );
        _; // if the statement above is true, then run the function body.
    }
    
    modifier onlyCarDealer{
        require(
            msg.sender == carDealer, 
            "Only CarDealer can call this function"
        );
        _; // if the statement above is true, then run the function body.
    }
    
    modifier onlyDriver{
        require(
            msg.sender == taxiDriver.identity,
            "Only Driver can call this function"
        );
        _; // if the statement above is true, then run the function body.
    }
    
    modifier onlyBefore(uint _time){ 
        require(block.timestamp <= _time, "Offer valid time is passed");
        _;
    }
    
    
    // Public, called by participants
    function joinFunction() public payable{
        require(isJoined[msg.sender] == false, "The participant have already joined.");
        require(msg.value >= participationFee, "Participants needs to pay enough participation fee");
        require(participants.length < 9, "Participant number must be maximum of 9");
        contractBalance += msg.value; // if the participant is allowed to be member of contract, increment contract balance
        participantByAddress[msg.sender] = Participant({p_address: payable(msg.sender), balance: 0 ether, proposedRepurchaseCarVote: false, proposedCarVote: false, proposedDriverVote: false});
        participants.push(participantByAddress[msg.sender]);
        isJoined[msg.sender] = true;
    }
    
    function setCarDealer(address payable _carDealer) onlyManager public{
        carDealer = _carDealer; // sets the CarDealer’s address
    }
    
    // Only CarDealer can call this
    // sets Proposed Car values, such as CarID, price, offer valid time and approval state (to 0)
    function carProposeToBusiness(bytes32 _carId, uint _price, uint _offerValidTime) onlyCarDealer public{
        proposedCar = ProposedCar({carId: _carId, price: _price, offerValidTime: _offerValidTime,
            approvalState: 0, isProposed: true
        });
        for(uint i=0;i<participants.length;i++){
            participantByAddress[participants[i].p_address].proposedCarVote = false;
        }
    }
    
    function approvePurchaseCar() onlyParticipant public{
        require(proposedCar.isProposed, "There is no any proposed car.");
        require(participantByAddress[msg.sender].proposedCarVote == false, "The participant have already approved the purchase car"); // check whether the related participant have already approved the purchase car or not 
        proposedCar.approvalState += 1; // if the condition above is satisfy, increment the approval state for approving the proposed purchase
        participantByAddress[msg.sender].proposedCarVote = true; //indicates the proposed purchase car is approved by the participant
    }
    
    // Only Manager can call this function
    // sends the CarDealer the price of the proposed car if the offer valid time is not passed yet and approval state is approved by more than half of the participants.
    function purchaseCar() onlyManager onlyBefore(proposedCar.offerValidTime) public{
        require(proposedCar.isProposed, "There is no any proposed car."); // Manager can not execute the function if a car is not proposed
        require(address(this).balance >= proposedCar.price, "There is no enough money in the contract...");
        require(proposedCar.approvalState > participants.length/2 , "Approval state must be approved by more than half of the participants");
        carDealer.transfer(proposedCar.price);
        proposedCar.isProposed = false; // indicates that the proposed car is purchased and can not purchased second time
        ownedCar = proposedCar.carId;
    }
    
    function repurchaseCarPropose(bytes32 _carId, uint _price, uint _offerValidTime) onlyCarDealer public{
        require(_carId == ownedCar, "Please enter a correct car id.");
        proposedRepurchase = ProposedCar({carId: _carId, price: _price, offerValidTime: _offerValidTime,
            approvalState: 0, isProposed: true
        });
        for(uint i=0;i<participants.length;i++){
            participantByAddress[participants[i].p_address].proposedRepurchaseCarVote = false;
        }
    }
    
    function approveSellProposal() onlyParticipant public{
        require(proposedRepurchase.isProposed, "There is no any proposed car");
        require(participantByAddress[msg.sender].proposedRepurchaseCarVote == false, "The participant have already approved");
        proposedRepurchase.approvalState += 1; // if the condition above is satisfy, increment the approval state for approving the proposed repurchase
        participantByAddress[msg.sender].proposedRepurchaseCarVote = true; //indicates the proposed repurchase car is approved by the participant
    }
    
    function repurchaseCar() onlyCarDealer onlyBefore(proposedRepurchase.offerValidTime) public payable{
        require(proposedRepurchase.isProposed, "There is no any proposed car");
        require(proposedRepurchase.approvalState > participants.length/2 , "Approval state must be approved by more than half of the participants");
        require(msg.sender.balance >= proposedRepurchase.price, "There is no enough money in the carDealer's balance");
        require(msg.value >= proposedRepurchase.price, "Car Dealer must send the proposed car price to the contract"); // if the offer valid time is not passed yet and approval state is approved by more than half of the participants
        //address(this).transfer(msg.value);
        delete ownedCar;
        contractBalance += msg.value; // sends the proposed car price to contract
        proposedRepurchase.isProposed = false;
    }
    
    function proposeDriver(address payable _driverAddress, uint _salary) onlyManager public{
        require(taxiDriver.identity == address(0), "There is already a driver."); // We assumed there is only 1 driver
        proposedDriver = ProposedDriver({
            proposedDriverIdentity: _driverAddress,
            approvalState:0,
            salary: _salary,
            isProposed: true
        });
        for(uint i=0;i<participants.length;i++){
            participantByAddress[participants[i].p_address].proposedDriverVote = false; // indicates that no participant has voted for the proposed driver.
        }
    }
    
    function approveDriver() onlyParticipant public{
        require(proposedDriver.isProposed, "There is no any proposed driver.");
        require(participantByAddress[msg.sender].proposedDriverVote == false, "The participant have already approved the proposed driver");
        proposedDriver.approvalState += 1; // if the condition above is satisfy, increment the approval state for approving the proposed driver
        participantByAddress[msg.sender].proposedDriverVote = true; //indicates the proposed driver is approved by the participant
    }
    
    function setDriver() onlyManager public{
        require(proposedDriver.isProposed, "There is no any proposed driver.");
        require(proposedDriver.approvalState > participants.length/2 , "Approval state must be approved by more than half of the participants");
        // if the above statement is satisfied, we can set the Taxi Driver
        taxiDriver = TaxiDriver({
            identity: proposedDriver.proposedDriverIdentity,
            salary: proposedDriver.salary,
            account: 0
        });
        releaseSalaryTime = block.timestamp;
    }
    
    function fireDriver() onlyManager public payable{
        require(taxiDriver.identity > address(0) , "The Driver is fired or not set...");
        require(address(this).balance >= taxiDriver.salary, "There is no enough money in the contract to give the full month of salary to account of current driver");
        contractBalance -= taxiDriver.salary;
        taxiDriver.account += taxiDriver.salary;
        taxiDriver.identity.transfer(taxiDriver.salary);
        delete taxiDriver; // reseting the address of driver
        //taxiDriver.identity = address(0); // reseting the address of driver
    }
    
    function payTaxiCharge() public payable{
        contractBalance += msg.value; // Charge is sent to contract
    }
    
    function releaseSalary() onlyManager public{
        require(taxiDriver.identity > address(0), "The Driver is fired or not set...");
        require(releaseSalaryTime + 30 days <= block.timestamp, "Manager can not be call this function more than once in a month.");
        //require(taxiDriver.salary <= address(this).balance, "There is no enough money in the contract.");
        require(taxiDriver.salary <= contractBalance, "There is no enough money in the contract.");
        //taxiDriver.identity.transfer(taxiDriver.salary);
        contractBalance -= taxiDriver.salary;
        releaseSalaryTime = block.timestamp;
        taxiDriver.account += taxiDriver.salary;
    }
    
    function getSalary() onlyDriver public payable{
        uint money = taxiDriver.account;
        require(money > 0, "There is no any money in Driver's account.");
        taxiDriver.account -= taxiDriver.account;
        taxiDriver.identity.transfer(money); // send to his/her address
    }
    
    function payCarExpenses() onlyManager public{
        require(payCarExpensesTime + 180 days <= block.timestamp, "Manager can not be call this function more than once in the last 6 months.");
        require(address(this).balance >= FixedExpenses, "There is no enough money in the contract.");
        carDealer.transfer(FixedExpenses);
        payCarExpensesTime = block.timestamp;
        contractBalance -= FixedExpenses;
    }
    
    function payDividend() onlyManager public{
        uint totalProfitAfterExpensesAndDriverSalaries = address(this).balance - FixedExpenses - taxiDriver.salary;
        require(totalProfitAfterExpensesAndDriverSalaries >= 0, "There is no enough money in the contract.");
        require(payDividendTime + 180 days <= block.timestamp, "Manager can not be call this function more than once in the last 6 months.");
        payDividendTime = block.timestamp;
        uint profitPerParticipant = totalProfitAfterExpensesAndDriverSalaries / (participants.length);
        for(uint i=0;i<participants.length;i++){
            participantByAddress[participants[i].p_address].balance += profitPerParticipant;
            totalProfitAfterExpensesAndDriverSalaries -= profitPerParticipant;
        }
    }
    
    function getDividend() onlyParticipant public payable{
        require(msg.sender.balance > 0, "there is no any money in the account of participant.");
        uint participantAccount = participantByAddress[msg.sender].balance;
        require(participantAccount != 0, "The getDividend function have already been executed.");
        if(participantAccount > 0){
            participantByAddress[msg.sender].balance = 0;
            payable(msg.sender).transfer(participantAccount);
        }
    }
    
    // fall back function - called if other functions do not match call or
    // sent ether without data 
    receive () external payable{  // for empty calldata (and any value)
        revert();
    }
    
    fallback() external{  // when no other function matches (not even the receive function).
        revert ();
    }
    
}
