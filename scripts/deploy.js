async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  const contract_deploy = await ethers.getContractFactory("DEX_4");
  const DEX = await contract_deploy.deploy();

  console.log("DEX address:", DEX.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
