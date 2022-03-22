echo "deploy begin....."

TF_CMD=node_modules/.bin/truffle-flattener

echo "" >  ./deployments/MerkleDistributor.full.sol
cat  ./scripts/head.sol >  ./deployments/MerkleDistributor.full.sol
$TF_CMD ./contracts/MerkleDistributor.sol >>  ./deployments/MerkleDistributor.full.sol 

echo "deploy end....."