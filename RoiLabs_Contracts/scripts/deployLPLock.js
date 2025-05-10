

const hre = require("hardhat");
require("dotenv").config();

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying LP Lock Contract with account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  
  const USDC_BASE_ADDRESS = process.env.USDC_BASE_ADDRESS;
  const PLATFORM_FEE_WALLET = process.env.PLATFORM_FEE_WALLET;

  const LPLock = await hre.ethers.getContractFactory("LPLock");
  const lpLock = await LPLock.deploy(USDC_BASE_ADDRESS, PLATFORM_FEE_WALLET);

  await lpLock.deployed();

  console.log("LPLock deployed to:", lpLock.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
