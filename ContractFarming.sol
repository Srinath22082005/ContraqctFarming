// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

contract ContractFarming {
    uint public _p_id = 0;
    uint public _c_id = 0;
    uint public _f_id = 0;

    address public regulator;

    constructor() {
        regulator = msg.sender; // Assuming the contract deployer is the regulator
    }

    modifier onlyRegulator() {
        require(msg.sender == regulator, "Only regulator can verify");
        _;
    }

    struct FarmContract {
        uint _contract_id;
        uint _farmer_id;
        uint _buyer_id;
        uint _quantity;
        uint _price;
        uint _startDate;
        uint _endDate;
        string _status; // "Pending", "In Progress", "Completed", "Cancelled"
    }

    mapping(uint => FarmContract) public contracts;

    struct Farmer {
        string _name;
        address _address;
        string _location;
    }

    mapping(uint => Farmer) public farmers;

    struct Buyer {
        string _name;
        address _address;
        string _location;
    }

    mapping(uint => Buyer) public buyers;

    struct Escrow {
        uint _contract_id;
        uint _amount;
        address _buyer;
        bool _fundsReleased;
    }

    mapping(uint => Escrow) public escrows;

    struct Dispute {
        uint _contract_id;
        string _reason;
        bool _resolved;
    }

    mapping(uint => Dispute) public disputes;

    struct Insurance {
        uint _contract_id;
        uint _premium;
        bool _insured;
        uint _payoutAmount;
    }

    mapping(uint => Insurance) public insurances;

    struct MultiSig {
        uint _contract_id;
        mapping(address => bool) _signatures;
        uint _signaturesCount;
        uint _requiredSignatures;
    }

    mapping(uint => MultiSig) public multisigs;

    // Events
    event ContractCreated(uint contract_id, uint farmer_id, uint buyer_id);
    event FundsReleased(uint contract_id, uint amount);
    event DisputeRaised(uint contract_id, string reason);
    event DisputeResolved(uint contract_id);
    event InsuranceClaimed(uint contract_id);

    function createFarmer(
        string memory name,
        address f_add,
        string memory location
    ) public returns (uint) {
        uint farmer_id = _f_id++;
        farmers[farmer_id]._name = name;
        farmers[farmer_id]._address = f_add;
        farmers[farmer_id]._location = location;

        return farmer_id;
    }

    function createBuyer(
        string memory name,
        address b_add,
        string memory location
    ) public returns (uint) {
        uint buyer_id = _c_id++;
        buyers[buyer_id]._name = name;
        buyers[buyer_id]._address = b_add;
        buyers[buyer_id]._location = location;

        return buyer_id;
    }

    function createContract(
        uint farmer_id,
        uint buyer_id,
        uint quantity,
        uint price,
        uint startDate,
        uint endDate
    ) public returns (uint) {
        require(farmer_id < _f_id, "Invalid Farmer ID");
        require(buyer_id < _c_id, "Invalid Buyer ID");

        uint contract_id = _p_id++;

        contracts[contract_id]._contract_id = contract_id;
        contracts[contract_id]._farmer_id = farmer_id;
        contracts[contract_id]._buyer_id = buyer_id;
        contracts[contract_id]._quantity = quantity;
        contracts[contract_id]._price = price;
        contracts[contract_id]._startDate = startDate;
        contracts[contract_id]._endDate = endDate;
        contracts[contract_id]._status = "Pending";

        emit ContractCreated(contract_id, farmer_id, buyer_id);

        return contract_id;
    }

    function createEscrow(uint contract_id) public payable {
        require(msg.value == contracts[contract_id]._price, "Incorrect payment amount");
        escrows[contract_id] = Escrow(contract_id, msg.value, msg.sender, false);
    }

    function releaseFunds(uint contract_id) internal {
        require(
            keccak256(abi.encodePacked(contracts[contract_id]._status)) ==
            keccak256(abi.encodePacked("Completed")),
            "Contract is not completed"
        );
        require(escrows[contract_id]._fundsReleased == false, "Funds already released");

        payable(farmers[contracts[contract_id]._farmer_id]._address).transfer(escrows[contract_id]._amount);
        escrows[contract_id]._fundsReleased = true;

        emit FundsReleased(contract_id, escrows[contract_id]._amount);
    }

    function applyPenalty(uint contract_id, uint penaltyAmount) public {
        require(
            msg.sender == farmers[contracts[contract_id]._farmer_id]._address || 
            msg.sender == buyers[contracts[contract_id]._buyer_id]._address,
            "Only farmer or buyer can apply penalty"
        );
        require(escrows[contract_id]._fundsReleased == false, "Funds already released");

        escrows[contract_id]._amount -= penaltyAmount;
    }

    function verifyCompletion(uint contract_id) public onlyRegulator {
        require(
            keccak256(abi.encodePacked(contracts[contract_id]._status)) ==
            keccak256(abi.encodePacked("In Progress")),
            "Contract is not in progress"
        );
        contracts[contract_id]._status = "Completed";
    }

    function raiseDispute(uint contract_id, string memory reason) public {
        require(
            msg.sender == farmers[contracts[contract_id]._farmer_id]._address || 
            msg.sender == buyers[contracts[contract_id]._buyer_id]._address,
            "Only farmer or buyer can raise dispute"
        );

        disputes[contract_id] = Dispute(contract_id, reason, false);

        emit DisputeRaised(contract_id, reason);
    }

    function resolveDispute(uint contract_id) public onlyRegulator {
        disputes[contract_id]._resolved = true;

        emit DisputeResolved(contract_id);
    }

    function buyInsurance(uint contract_id, uint premium) public payable {
        require(msg.value == premium, "Incorrect premium amount");
        insurances[contract_id] = Insurance(contract_id, premium, true, premium * 2); // Example payout: 2x premium
    }

    function claimInsurance(uint contract_id) public onlyRegulator {
        require(insurances[contract_id]._insured == true, "Contract not insured");
        require(disputes[contract_id]._resolved == true, "Dispute not resolved");

        payable(farmers[contracts[contract_id]._farmer_id]._address).transfer(insurances[contract_id]._payoutAmount);
        insurances[contract_id]._insured = false; // Mark insurance as claimed

        emit InsuranceClaimed(contract_id);
    }

    function createMultiSig(uint contract_id, uint requiredSignatures) public {
        multisigs[contract_id]._contract_id = contract_id;
        multisigs[contract_id]._requiredSignatures = requiredSignatures;
    }

    function signContract(uint contract_id) public {
        require(
            msg.sender == farmers[contracts[contract_id]._farmer_id]._address || 
            msg.sender == buyers[contracts[contract_id]._buyer_id]._address || 
            msg.sender == regulator,
            "Only farmer, buyer or regulator can sign"
        );
        require(multisigs[contract_id]._signatures[msg.sender] == false, "Already signed");

        multisigs[contract_id]._signatures[msg.sender] = true;
        multisigs[contract_id]._signaturesCount++;

        if (multisigs[contract_id]._signaturesCount >= multisigs[contract_id]._requiredSignatures) {
            releaseFunds(contract_id);
        }
    }

    function getFarmerDetails(uint farmer_id) public view returns (string memory,address,string memory)
    {
        Farmer memory farmer = farmers[farmer_id];
        return (farmer._name, farmer._address, farmer._location);
    }

    function getBuyerDetails(uint buyer_id)public view returns (string memory,address,string memory)
    {
        Buyer memory buyer = buyers[buyer_id];
        return (buyer._name, buyer._address, buyer._location);
    }

    function getContractDetails(uint contract_id)
        public
        view
        returns (
            uint,
            uint,
            uint,
            uint,
            uint,
            uint,
            string memory
        )
    {
        FarmContract memory farmContract = contracts[contract_id];
        return (
            farmContract._contract_id,
            farmContract._farmer_id,
            farmContract._buyer_id,
            farmContract._quantity,
            farmContract._price,
            farmContract._startDate,
            farmContract._endDate,
            farmContract._status,
        ); // Ensure the number of returned values matches the function signature
    }

}
