const { ethers } = require("hardhat")

const networkConfig = [
    {
        name: "hardhat",
        poolAddressesProvider: "0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D",
        wethAddress: "0x2e3A2fb8473316A02b8A297B982498E661E1f6f5",
        weithATokenWhale: "0xd89961f5aff8c9f0a106ca0bc4d8146da9db3c24",
        weithAToken: "0x27B4692C93959048833f40702b22FE3578E77759",
        wethGateway: "0xd5B55D3Ed89FDa19124ceB5baB620328287b915d",
        lockTime: 24 * 60 * 60,
        chainId: 31337
    },
    {
        name: "localhost",
        keepersUpdateInterval: "30",
        lockTime: 24 * 60 * 60,
        chainId: 31337
    },
    {
        name: "goerli",
        poolAddressesProvider: "0xc4dCB5126a3AfEd129BC3668Ea19285A9f56D15D",
        wethAddress: "0x2e3A2fb8473316A02b8A297B982498E661E1f6f5",
        weithATokenWhale: "0xd89961f5aff8c9f0a106ca0bc4d8146da9db3c24",
        weithAToken: "0x27B4692C93959048833f40702b22FE3578E77759",
        wethGateway: "0xd5B55D3Ed89FDa19124ceB5baB620328287b915d",
        lockTime: 24 * 60 * 60,
        chainId: 5
    },
    {
        name: "mainnet",
        keepersUpdateInterval: "30",
        chainId: 1
    },
]

const developmentChains = ["hardhat", "localhost"]

export default { networkConfig, developmentChains }