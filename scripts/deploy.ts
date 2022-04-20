// scripts/deploy.js
import { ethers, artifacts } from "hardhat";
import type { ChainlinkTwoFeedPriceOracleFactory } from "../typechain/ChainlinkTwoFeedPriceOracleFactory";
import type { ChainlinkTwoFeedPriceOracle } from "../typechain/ChainlinkTwoFeedPriceOracle";
import type { ChainlinkFeedPriceOracleFactory } from "../typechain/ChainlinkFeedPriceOracleFactory";
import type { ChainlinkFeedPriceOracle } from "../typechain/ChainlinkFeedPriceOracle";
import type { NativeGildFactory } from "../typechain/NativeGildFactory";
import type { NativeGild } from "../typechain/NativeGild";

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
    console.log("tx",tx)
      
    await chainlinkTwoFeedPriceOracle.deployed();
    console.log('chainlinkTwoFeedPriceOracle deployed to:', chainlinkTwoFeedPriceOracle.address);


  let gildConfig = {
    name: "EthGild",
    symbol: "ETHg",
    uri: "ipfs://bafkreiahuttak2jvjzsd4r62xoxb4e2mhphb66o4cl2ntegnjridtyqnz4",
    erc20OverburnNumerator: 1001,
    erc20OverburnDenominator: 1000,
    priceOracle: chainlinkTwoFeedPriceOracle.address, 
  }

    const nativeGildFactoryFactory = await ethers.getContractFactory(
      "NativeGildFactory"
    );
  
    const nativeGildFactory = 
      (await nativeGildFactoryFactory.deploy()) as NativeGildFactory
  
    await nativeGildFactory.deployed();
    console.log('nativeGildFactoryFactory deployed to:', nativeGildFactory.address);
  
  
    const nativeGildTx = await nativeGildFactory.createChildTyped(gildConfig);
    const nativeGild = new ethers.Contract(
      ethers.utils.hexZeroPad(
        ethers.utils.hexStripZeros(
          (await getEventArgs(nativeGildTx, "NewChild", nativeGildFactory)).child
        ),
        20
      ),
      (await artifacts.readArtifact("NativeGild")).abi,
      deployer
  
    ) as NativeGild & Contract;

    console.log("nativeGildTx", nativeGildTx)
  
    await nativeGild.deployed();
    console.log('NativeGild deployed to:', nativeGild.address);

}

  main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });