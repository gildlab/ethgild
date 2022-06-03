// scripts/deploy.js
import { ethers, artifacts } from "hardhat";
import type { ChainlinkTwoFeedPriceOracleFactory } from "../typechain/ChainlinkTwoFeedPriceOracleFactory";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { ERC20GildFactory } from "../typechain/ERC20GildFactory";
import type { ERC20Gild } from "../typechain/ERC20Gild";

import type { Contract } from "ethers";
import { getEventArgs } from "../test/util"

async function main () {
    const [deployer] = await ethers.getSigners();


    const rinkebyXauUsd = "0x81570059A0cb83888f1459Ec66Aad1Ac16730243";
    const rinkebyEthUsd = "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e";
    
    const polygonXauUsd = "0x0C466540B2ee1a31b441671eac0ca886e051E410";
    const polygonMaticUsd = "0xab594600376ec9fd91f8e885dadf0ce036862de0";

    let chainlinkTwoFeedPriceOracle = null;

    const chainlinkTwoFeedPriceOracleConfig = {
        rinkeby: {
        base: rinkebyEthUsd,
        quote: rinkebyXauUsd,
        },
        polygon: {
        base: polygonMaticUsd,
        quote: polygonXauUsd,
        }
    } 


    const chainlinkTwoFeedPriceOracleFactoryFactory = await ethers.getContractFactory(
      "ChainlinkTwoFeedPriceOracleFactory"
    );
    
    const chainlinkTwoFeedPriceOracleFactory = 
    (await chainlinkTwoFeedPriceOracleFactoryFactory.deploy()) as ChainlinkTwoFeedPriceOracleFactory
    
    await chainlinkTwoFeedPriceOracleFactory.deployed();
    console.log('chainlinkTwoFeedPriceOracleFactory deployed to:', chainlinkTwoFeedPriceOracleFactory.address);
    
    
    const tx = await chainlinkTwoFeedPriceOracleFactory.createChildTyped(chainlinkTwoFeedPriceOracleConfig.polygon);
    chainlinkTwoFeedPriceOracle = new ethers.Contract(
    ethers.utils.hexZeroPad(
      ethers.utils.hexStripZeros(
        (await getEventArgs(tx, "NewChild", chainlinkTwoFeedPriceOracleFactory)).child
      ),
      20
    ),

    
    (await artifacts.readArtifact("ChainlinkTwoFeedPriceOracle")).abi,
    deployer
      
    ) as ChainlinkTwoFeedPriceOracle & Contract;
      
    await chainlinkTwoFeedPriceOracle.deployed();
    console.log('chainlinkTwoFeedPriceOracle deployed to:', chainlinkTwoFeedPriceOracle.address);

    const erc20ContractAddress = "0xc778417E063141139Fce010982780140Aa0cD5Ab"

    let gildConfig = {
        asset: erc20ContractAddress,
        name: "EthGild",
        symbol: "ETHg",
        uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
        priceOracle: chainlinkTwoFeedPriceOracle.address,
    }


    const erc20GildFactoryFactory = await ethers.getContractFactory(
      "ERC20GildFactory"
    );
  
    const erc20GildFactory = 
      (await erc20GildFactoryFactory.deploy()) as ERC20GildFactory
  
    await erc20GildFactory.deployed();
    console.log('ERC20GildFactoryFactory deployed to:', erc20GildFactory.address);
  
  
    const erc20GildTx = await erc20GildFactory.createChildTyped(gildConfig);
    const erc20Gild = new ethers.Contract(
      ethers.utils.hexZeroPad(
        ethers.utils.hexStripZeros(
          (await getEventArgs(erc20GildTx, "NewChild", erc20GildFactory)).child
        ),
        20
      ), 
      (await artifacts.readArtifact("ERC20Gild")).abi,
      deployer
  
    ) as ERC20Gild & Contract;

    await erc20Gild.deployed();
    console.log('ERC20Gild deployed to:', erc20Gild.address);

}

  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });