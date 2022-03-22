// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMerkleDistributor.sol";

contract MerkleDistributor is IMerkleDistributor, Ownable {
    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    
    uint256 public endTime;
    address public withdrawAddress;

    // This is a packed array of booleans.
    mapping(uint256 => uint256) private claimedBitMap;
    
    // black list
    mapping(address => bool) public blackAccountMap;

    event Claimed(uint256 index, address account, uint256 amount);
    event UpdateEndTime(uint256 endTime);
    event UpdateWithdrawAddress(address withdrawAddress);
    
    event AddBlackAccount(address blackAccount);
    event DelBlackAccount(address blackAccount);
    event EmergencyWithdraw(address account, uint256 banlance);

    constructor(address token_, bytes32 merkleRoot_, uint256 _endTime, address _withdrawAddress) public {
        token = token_;
        merkleRoot = merkleRoot_;
        endTime = _endTime;
        withdrawAddress = _withdrawAddress;
    }

    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] = claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    function claim(uint256 index, uint256 amount, bytes32[] calldata merkleProof) external override {
        require(!isClaimed(index), 'MerkleDistributor: Drop already claimed.');
        require(endTime >= block.timestamp, 'MerkleDistributor: Drop already end.');

        address account = msg.sender;
        require(!blackAccountMap[account], "MerkleDistributor: in black list");

        // Verify the merkle proof.
        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), 'MerkleDistributor: Invalid proof.');

        // Mark it claimed and send the token.
        _setClaimed(index);
        require(IERC20(token).transfer(account, amount), 'MerkleDistributor: Transfer failed.');

        emit Claimed(index, account, amount);
    }

    function withdraw() external {
        require(
            block.timestamp > endTime,
            'MerkleDistributor: Withdraw failed, cannot claim until after validBlocks diff'
        );
        require(
            IERC20(token).transfer(withdrawAddress, IERC20(token).balanceOf(address(this))),
            'MerkleDistributor: Withdraw transfer failed.'
        );
    }

    function emergencyWithdraw(address withdrawAddr) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(withdrawAddr, balance);
        emit EmergencyWithdraw(withdrawAddr, balance);
    }
    
    function addBlackAccount(address _blackAccount) public onlyOwner {
        require(!blackAccountMap[_blackAccount], "MerkleDistributor: has in black list");
        blackAccountMap[_blackAccount] = true;
        emit AddBlackAccount(_blackAccount);
    }

    function delBlackAccount(address _blackAccount) public onlyOwner {
        require(blackAccountMap[_blackAccount], "MerkleDistributor: not in black list");

        blackAccountMap[_blackAccount] = false;
        emit DelBlackAccount(_blackAccount);
    }

    function updateEndTime(uint256 _endTime) external onlyOwner {
        endTime = _endTime;
        emit UpdateEndTime(endTime);
    }

    function updateWithdrawAddress(address _withdrawAddress) external onlyOwner {
        withdrawAddress = _withdrawAddress;
        emit UpdateWithdrawAddress(withdrawAddress);
    }
}
