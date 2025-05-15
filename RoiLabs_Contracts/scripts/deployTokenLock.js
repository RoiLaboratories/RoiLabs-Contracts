const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log(`Deploying TokenLock contract with account: ${deployer.address}`);
  console.log(`Account balance: ${(await deployer.getBalance()).toString()}`);

  const TokenLock = await ethers.getContractFactory("TokenLock");
  const tokenLock = await TokenLock.deploy();

  await tokenLock.deployed();

  console.log(`TokenLock deployed at: ${tokenLock.address}`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
