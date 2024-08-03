import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ExchangeTokenModule = buildModule("ExchangeTokenModule", (m) => {
  const exchange = m.contract("ExchangeTokenModule");

  return { exchange };
});

export default ExchangeTokenModule;
