require("@nomiclabs/hardhat-ethers");
require("dotenv").config();

module.exports = {
  solidity: "0.8.20",
  defaultNetwork: "base",
  networks: {
    base: {
      url: process.env.RPC_URL,
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
};
