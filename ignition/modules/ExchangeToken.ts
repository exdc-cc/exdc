import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ExchangeToken = buildModule("ExchangeToken", (m) => {
  const exchange = m.contract("ExchangeToken", ["0x338b7Ed75478D995E0c44cB4BDEDf83a6f47F665", "Exchange", "EXDC"]);

  return { exchange };
});

export default ExchangeToken;
