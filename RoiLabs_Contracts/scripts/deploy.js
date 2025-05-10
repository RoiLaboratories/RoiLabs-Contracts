const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const routerAddress = process.env.ROUTER_ADDRESS;

  const RoiToken = await hre.ethers.getContractFactory("RoiToken");
  const token = await RoiToken.deploy(routerAddress);

  await token.deployed();

  console.log("RoiToken deployed to:", token.address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
