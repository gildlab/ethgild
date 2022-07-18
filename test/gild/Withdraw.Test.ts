// import chai from "chai";
// import {solidity} from "ethereum-waffle";
// import {ethers} from "hardhat";
// import {
//   assertError,
//   deployERC20PriceOracleVault,
//   fixedPointDiv,
//   fixedPointMul,
//   ADDRESS_ZERO,
// } from "../util";
// import {DepositEvent} from "../../typechain/IERC4626";
// import {SignerWithAddress} from "@nomiclabs/hardhat-ethers/signers";
// import {
//   ReceiptInformationEvent,
//   DepositWithReceiptEvent,
// } from "../../typechain/ReceiptVault";
//
// import {getEventArgs} from "../util";
//
// let owner: SignerWithAddress;
//
// chai.use(solidity);
//
// const {assert} = chai;
//
// describe("Withdraw", async function () {
//   it("Withdraws", async function () {
//     const signers = await ethers.getSigners();
//     const alice = signers[0];
//     const bob = signers[1];
//
//     const [vault, asset, priceOracle] = await deployERC20PriceOracleVault();
//
//     const totalTokenSupply = await asset.totalSupply();
//
//     const transferAmount = ethers.BigNumber.from(100)//totalTokenSupply.div(2);
//
//     await asset.connect(alice).increaseAllowance(vault.address, transferAmount);
//
//     // give alice reserve to cover cost
//     await asset.transfer(bob.address, transferAmount);
//
//     // Min gild price MUST be respected
//     const price = await priceOracle.price();
//     const id1155 = price
//
//
//     const depositTx = await vault
//       .connect(alice)["deposit(uint256,address,uint256,bytes)"](
//       transferAmount,
//       bob.address,
//       price,
//       []
//     );
//     const bobBalance = await vault["balanceOf(address)"](bob.address);
//     console.log("bobBalance",bobBalance)
//     const shares = bobBalance
//
//     depositTx.wait()
//
//     const erc1155Balance = await vault["balanceOf(address,uint256)"](
//       bob.address,
//       id1155
//     );
//
//     console.log(1, erc1155Balance, shares)
//
//     const expectedShares = fixedPointMul(transferAmount, price).add(1)
//
//     await asset.connect(bob).increaseAllowance(vault.address, shares);
//
//     // give alice reserve to cover cost
//     await asset.transfer(bob.address, transferAmount);
//
//     await vault
//       .connect(alice)
//       ["withdraw(uint256,address,address,uint256)"](shares, bob.address, bob.address, price);
//     const sharesaft = await vault["balanceOf(address)"](bob.address);
//     console.log(2, erc1155Balance, shares)
//
//     console.log(expectedShares, sharesaft)
//
//     // assert(
//     //   vaultAsset === asset.address,
//     //   `Wrong asset address ${asset.address} ${vaultAsset}`
//     // );
//   })
// })
