syam@LAPTOP-IBEUNTHH:~/dev/Project/RetroPick/V1/contract$ forge test --rerun -vvvv
[⠊] Compiling...
No files changed, compilation skipped

Ran 2 tests for test/markettype/MarketTypeAll15.t.sol:MarketTypeAll15Test
[FAIL: InvalidReporterSignature()] test_marketType_09_corridor_stablecoin_with_tro_ohlc() (gas: 1235631)
Traces:
  [49444064] MarketTypeAll15Test::setUp()
    ├─ [787511] → new MockERC20@0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    │   └─ ← [Return] 3706 bytes of code
    ├─ [209649] → new MockPriceOracle@0x2e234DAe75C793f67A35089C9d99245E1C58470b
    │   └─ ← [Return] 1047 bytes of code
    ├─ [11254358] → new MarketEngineDispatcher@0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    │   ├─ emit Initialized(version: 18446744073709551615 [1.844e19])
    │   └─ ← [Return] 56069 bytes of code
    ├─ [249759] → new ERC1967Proxy@0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    │   ├─ emit Upgraded(implementation: MarketEngineDispatcher: [0xF62849F9A0B5Bf2913b396098F7c7019b51A820a])
    │   ├─ [191688] MarketEngineDispatcher::initialize(InitConfig({ stakeToken: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, priceOracle: 0x2e234DAe75C793f67A35089C9d99245E1C58470b, admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, worker: 0x0000000000000000000000000000000000000B0b, defaultSettlementFeeBps: 100, maxSwitchFeeBps: 500, maxOutcomes: 8, oracleKind: 0, oracleMaxDelaySeconds: 3600, oracleMaxConfidenceBps: 10000 [1e4] })) [delegatecall]
    │   │   ├─ emit ConfigInitialized(admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, workerAuthority: 0x0000000000000000000000000000000000000B0b)
    │   │   ├─ emit Initialized(version: 1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return] 158 bytes of code
    ├─ [3445642] → new MarketEngineAdminModule@0xc7183455a4C133Ae270771860664b6B7ec320bB1
    │   └─ ← [Return] 17209 bytes of code
    ├─ [5702336] → new MarketEngineViewModule@0xa0Cb889707d426A7A386870A03bc70d1b0697598
    │   └─ ← [Return] 28477 bytes of code
    ├─ [3722194] → new MarketEngineUserOpsClaimsModule@0x1d1499e622D69689cdf9004d05Ec547d650Ff211
    │   └─ ← [Return] 18590 bytes of code
    ├─ [9278232] → new MarketEngineCoreLifecycleModule@0xA4AD4f68d0b91CFD19687c881e50f3A00242828c
    │   └─ ← [Return] 46327 bytes of code
    ├─ [7944292] → new MarketEngineRollingLifecycleModule@0x03A6a84cD762D9707A21605b548aaaB891562aAb
    │   └─ ← [Return] 39669 bytes of code
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57028] ERC1967Proxy::fallback(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [56551] MarketEngineDispatcher::registerModule(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [62296] ERC1967Proxy::fallback(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [61819] MarketEngineDispatcher::registerModule(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57667] ERC1967Proxy::fallback(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [57190] MarketEngineDispatcher::registerModule(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [71484] ERC1967Proxy::fallback(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [71007] MarketEngineDispatcher::registerModule(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [67868] ERC1967Proxy::fallback(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [67391] MarketEngineDispatcher::registerModule(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa676be29, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf0f44260, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x8db50d4d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4f6916d1, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x54977e3c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x93a49e9f, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcf3c99bd, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x2b0957d5, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7db6585d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa225f18e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdfaa5f2e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdbb97b54, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x939cab22, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf8937fae, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x23a70c21, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x74adbb70, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0469435b, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5bd55b1c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe2fe583d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6ec3a91d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xda08b78a, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xca033f13, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4b4b06dc, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1ba9ad96, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc64198d3, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb4456653, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe78284e2, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6b4b0859, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x37f940d0, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x775b5370, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x72a85b43, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x779875ab, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe41dcb24, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb9131821, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb701cace, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc7dbf2cb, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5ca3e1e9, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa6b6d8d1, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcd869e04, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x778acc3c, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdf50de60, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1310276e, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x00de7b12, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf1282803, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7de2ec76, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x658ec38a, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xfb515038, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xd4256b4b, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6d9754a4, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa584ce58, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0f3ed99e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x75fb689e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xafe53192, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [209649] → new MockPriceOracle@0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    │   └─ ← [Return] 1047 bytes of code
    ├─ [209649] → new MockPriceOracle@0x15cF58144EF33af1e14b5208015d11F9143E27b9
    │   └─ ← [Return] 1047 bytes of code
    ├─ [209649] → new MockPriceOracle@0x212224D2F2d262cd093eE13240ca4873fcCBbA3C
    │   └─ ← [Return] 1047 bytes of code
    ├─ [0] VM::addr(<pk>) [staticcall]
    │   └─ ← [Return] 0x6E9972213BF459853FA33E28Ab7219e9157C8d02
    ├─ [2320548] → new TrustedReporterAdapter@0x2a07706473244BC757E10F2a9E86fB532828afe3
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x00000000000000000000000000000000000A11cE)
    │   ├─ emit MaxSignatureAgeUpdated(previousSeconds: 0, newSeconds: 3600)
    │   └─ ← [Return] 11214 bytes of code
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [25437] ERC1967Proxy::fallback(MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF])
    │   ├─ [24963] MarketEngineDispatcher::setRateOracle(MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF]) [delegatecall]
    │   │   ├─ emit RateOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [25460] ERC1967Proxy::fallback(MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9])
    │   ├─ [24986] MarketEngineDispatcher::setSmartDataOracle(MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9]) [delegatecall]
    │   │   ├─ emit SmartDataOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [25436] ERC1967Proxy::fallback(MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C])
    │   ├─ [24962] MarketEngineDispatcher::setMacroOracle(MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C]) [delegatecall]
    │   │   ├─ emit MacroOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [47293] MockERC20::mint(0x0000000000000000000000000000000000A11ce1, 1000000000000000000000000 [1e24])
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x0000000000000000000000000000000000A11ce1, value: 1000000000000000000000000 [1e24])
    │   └─ ← [Stop]
    ├─ [25393] MockERC20::mint(0x000000000000000000000000000000000000b0b1, 1000000000000000000000000 [1e24])
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x000000000000000000000000000000000000b0b1, value: 1000000000000000000000000 [1e24])
    │   └─ ← [Stop]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [25298] MockERC20::approve(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   ├─ emit Approval(owner: 0x0000000000000000000000000000000000A11ce1, spender: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   └─ ← [Return] true
    ├─ [0] VM::prank(0x000000000000000000000000000000000000b0b1)
    │   └─ ← [Return]
    ├─ [25298] MockERC20::approve(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   ├─ emit Approval(owner: 0x000000000000000000000000000000000000b0b1, spender: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   └─ ← [Return] true
    └─ ← [Stop]

  [1235631] MarketTypeAll15Test::test_marketType_09_corridor_stablecoin_with_tro_ohlc()
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [296133] ERC1967Proxy::fallback(UpsertTemplateParams({ slug: "mt-corridor-usdc", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 7, condition: 0, thresholdRule: 0, active: true, outcomeCount: 3, absoluteThresholdValueE8: 0, rangeBoundsE8: [99500000 [9.95e7], 100500000 [1.005e8], 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] }))
    │   ├─ [290726] MarketEngineDispatcher::fallback(UpsertTemplateParams({ slug: "mt-corridor-usdc", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 7, condition: 0, thresholdRule: 0, active: true, outcomeCount: 3, absoluteThresholdValueE8: 0, rangeBoundsE8: [99500000 [9.95e7], 100500000 [1.005e8], 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [257307] MarketEngineCoreLifecycleModule::upsertTemplate(UpsertTemplateParams({ slug: "mt-corridor-usdc", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 7, condition: 0, thresholdRule: 0, active: true, outcomeCount: 3, absoluteThresholdValueE8: 0, rangeBoundsE8: [99500000 [9.95e7], 100500000 [1.005e8], 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   ├─ emit TemplateUpserted(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, slug: "mt-corridor-usdc", marketType: 7, outcomeCount: 3, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [1770] ERC1967Proxy::fallback("mt-corridor-usdc") [staticcall]
    │   ├─ [1284] MarketEngineDispatcher::templateIdFromSlug("mt-corridor-usdc") [delegatecall]
    │   │   └─ ← [Return] 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487
    │   └─ ← [Return] 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487
    ├─ [28467] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487)
    │   ├─ [27993] MarketEngineDispatcher::initializeMarket(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487) [delegatecall]
    │   │   ├─ emit MarketInitialized(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [38217] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487) [staticcall]
    │   ├─ [37292] MarketEngineDispatcher::templates(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487) [delegatecall]
    │   │   └─ ← [Return] Template({ version: 1, marketType: 7, condition: 0, thresholdRule: 0, active: true, outcomeCount: 3, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, slug: "mt-corridor-usdc", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, absoluteThresholdValueE8: 0, rangeBoundsE8: [99500000 [9.95e7], 100500000 [1.005e8], 0, 0, 0, 0, 0], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })
    │   └─ ← [Return] Template({ version: 1, marketType: 7, condition: 0, thresholdRule: 0, active: true, outcomeCount: 3, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, slug: "mt-corridor-usdc", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, absoluteThresholdValueE8: 0, rangeBoundsE8: [99500000 [9.95e7], 100500000 [1.005e8], 0, 0, 0, 0, 0], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })
    ├─ [0] VM::warp(1080000 [1.08e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [198234] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 1080100 [1.08e6], 1080200 [1.08e6], 1080300 [1.08e6])
    │   ├─ [197739] MarketEngineDispatcher::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 1080100 [1.08e6], 1080200 [1.08e6], 1080300 [1.08e6]) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [171021] MarketEngineCoreLifecycleModule::openEpoch(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 1080100 [1.08e6], 1080200 [1.08e6], 1080300 [1.08e6]) [delegatecall]
    │   │   │   ├─ emit EpochOpened(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, openAt: 1080100 [1.08e6], lockAt: 1080200 [1.08e6], resolveAt: 1080300 [1.08e6])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1080150 [1.08e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [275915] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 0, 80000000000000000000 [8e19])
    │   ├─ [275426] MarketEngineDispatcher::depositToSide(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 0, 80000000000000000000 [8e19]) [delegatecall]
    │   │   ├─ [33166] MockERC20::transferFrom(0x0000000000000000000000000000000000A11ce1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 80000000000000000000 [8e19])
    │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000A11ce1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 80000000000000000000 [8e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit UserEpochIndexed(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1)
    │   │   ├─ emit PositionDeposited(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1, outcome: 0, amount: 80000000000000000000 [8e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x000000000000000000000000000000000000b0b1)
    │   └─ ← [Return]
    ├─ [181815] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 1, 80000000000000000000 [8e19])
    │   ├─ [181326] MarketEngineDispatcher::depositToSide(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 1, 80000000000000000000 [8e19]) [delegatecall]
    │   │   ├─ [11266] MockERC20::transferFrom(0x000000000000000000000000000000000000b0b1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 80000000000000000000 [8e19])
    │   │   │   ├─ emit Transfer(from: 0x000000000000000000000000000000000000b0b1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 80000000000000000000 [8e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit UserEpochIndexed(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, user: 0x000000000000000000000000000000000000b0b1)
    │   │   ├─ emit PositionDeposited(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, user: 0x000000000000000000000000000000000000b0b1, outcome: 1, amount: 80000000000000000000 [8e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [61508] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 2, 80000000000000000000 [8e19])
    │   ├─ [61019] MarketEngineDispatcher::depositToSide(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1, 2, 80000000000000000000 [8e19]) [delegatecall]
    │   │   ├─ [4466] MockERC20::transferFrom(0x0000000000000000000000000000000000A11ce1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 80000000000000000000 [8e19])
    │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000A11ce1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 80000000000000000000 [8e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit PositionDeposited(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1, outcome: 2, amount: 80000000000000000000 [8e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1080200 [1.08e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [41937] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1)
    │   ├─ [41460] MarketEngineDispatcher::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [14750] MarketEngineCoreLifecycleModule::lockEpoch(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1) [delegatecall]
    │   │   │   ├─ emit EpochLocked(templateId: 0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, epochId: 1, checkpointAValueE8: 0, publishTime: 0)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1080300 [1.08e6])
    │   └─ ← [Return]
    ├─ [1825] ERC1967Proxy::fallback(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1) [staticcall]
    │   ├─ [1345] MarketEngineDispatcher::positionKey(0x822082289cc4eb0b0a94971d92d5e8baec14165f73ec69b5092f580efacc5487, 1) [delegatecall]
    │   │   └─ ← [Return] 0x8c139bc4076ce339263f336d5bef53b5cac61ddb18aabb2c1cb8d3a9bc8c1525
    │   └─ ← [Return] 0x8c139bc4076ce339263f336d5bef53b5cac61ddb18aabb2c1cb8d3a9bc8c1525
    ├─ [0] VM::sign("<pk>", 0xf6c4b5629135ba226854474924006a3b4f425eaf20cfec277be75152f211905a) [staticcall]
    │   └─ ← [Return] 28, 0xd75b3e4463aa96803594ae1a8489b2e24084b2aca192397d6ad23e6b3c98df2a, 0x6ad54fa862dbb7e3f5f9b913cb9b8898a4aee213d491ebe9697e7c442122b23e
    ├─ [20579] TrustedReporterAdapter::postOhlcResult(0x8c139bc4076ce339263f336d5bef53b5cac61ddb18aabb2c1cb8d3a9bc8c1525, 100300000 [1.003e8], 99700000 [9.97e7], 100000000 [1e8], 1080300 [1.08e6], 0x03a30c5c83f84f53d375aeb9d420c63f1ba6bfb0fc8e54f6f1dc9c4653eb9b98, 0xd75b3e4463aa96803594ae1a8489b2e24084b2aca192397d6ad23e6b3c98df2a6ad54fa862dbb7e3f5f9b913cb9b8898a4aee213d491ebe9697e7c442122b23e1c)
    │   ├─ [3000] PRECOMPILES::ecrecover(0x165bc4ea3e63fe3652aa8c3bfbd1be08278e55d8609052c93513baf14a638a2b, 28, 97408475280343073519817872165892184414223083251880380803665724223161611378474, 48322050152267461024247731080488120301374372004759618077938790354458685649470) [staticcall]
    │   │   └─ ← [Return] 0xF96a5D5af44A9BEe1534c547943E4430985cCA5a
    │   └─ ← [Revert] InvalidReporterSignature()
    └─ ← [Revert] InvalidReporterSignature()

Warning: Replayed invariant failure from "/home/asyam/dev/Project/RetroPick/V1/contract/cache/invariant/failures/MarketEngineRoutedRecoveryInvariants/invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal" file.
Run `forge clean` or remove file to ignore failure and to continue invariant test campaign.
Backtrace:
  at TrustedReporterAdapter.postOhlcResult
  at MarketTypeAll15Test.test_marketType_09_corridor_stablecoin_with_tro_ohlc

[FAIL: InvalidReporterSignature()] test_marketType_10_cascade_downward_support_breaks() (gas: 1382098)
Traces:
  [49444064] MarketTypeAll15Test::setUp()
    ├─ [787511] → new MockERC20@0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    │   └─ ← [Return] 3706 bytes of code
    ├─ [209649] → new MockPriceOracle@0x2e234DAe75C793f67A35089C9d99245E1C58470b
    │   └─ ← [Return] 1047 bytes of code
    ├─ [11254358] → new MarketEngineDispatcher@0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    │   ├─ emit Initialized(version: 18446744073709551615 [1.844e19])
    │   └─ ← [Return] 56069 bytes of code
    ├─ [249759] → new ERC1967Proxy@0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    │   ├─ emit Upgraded(implementation: MarketEngineDispatcher: [0xF62849F9A0B5Bf2913b396098F7c7019b51A820a])
    │   ├─ [191688] MarketEngineDispatcher::initialize(InitConfig({ stakeToken: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, priceOracle: 0x2e234DAe75C793f67A35089C9d99245E1C58470b, admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, worker: 0x0000000000000000000000000000000000000B0b, defaultSettlementFeeBps: 100, maxSwitchFeeBps: 500, maxOutcomes: 8, oracleKind: 0, oracleMaxDelaySeconds: 3600, oracleMaxConfidenceBps: 10000 [1e4] })) [delegatecall]
    │   │   ├─ emit ConfigInitialized(admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, workerAuthority: 0x0000000000000000000000000000000000000B0b)
    │   │   ├─ emit Initialized(version: 1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return] 158 bytes of code
    ├─ [3445642] → new MarketEngineAdminModule@0xc7183455a4C133Ae270771860664b6B7ec320bB1
    │   └─ ← [Return] 17209 bytes of code
    ├─ [5702336] → new MarketEngineViewModule@0xa0Cb889707d426A7A386870A03bc70d1b0697598
    │   └─ ← [Return] 28477 bytes of code
    ├─ [3722194] → new MarketEngineUserOpsClaimsModule@0x1d1499e622D69689cdf9004d05Ec547d650Ff211
    │   └─ ← [Return] 18590 bytes of code
    ├─ [9278232] → new MarketEngineCoreLifecycleModule@0xA4AD4f68d0b91CFD19687c881e50f3A00242828c
    │   └─ ← [Return] 46327 bytes of code
    ├─ [7944292] → new MarketEngineRollingLifecycleModule@0x03A6a84cD762D9707A21605b548aaaB891562aAb
    │   └─ ← [Return] 39669 bytes of code
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57028] ERC1967Proxy::fallback(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [56551] MarketEngineDispatcher::registerModule(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [62296] ERC1967Proxy::fallback(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [61819] MarketEngineDispatcher::registerModule(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57667] ERC1967Proxy::fallback(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [57190] MarketEngineDispatcher::registerModule(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [71484] ERC1967Proxy::fallback(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [71007] MarketEngineDispatcher::registerModule(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [67868] ERC1967Proxy::fallback(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [67391] MarketEngineDispatcher::registerModule(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa676be29, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf0f44260, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x8db50d4d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4f6916d1, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x54977e3c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x93a49e9f, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcf3c99bd, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x2b0957d5, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7db6585d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa225f18e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdfaa5f2e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdbb97b54, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x939cab22, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf8937fae, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x23a70c21, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x74adbb70, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0469435b, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5bd55b1c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe2fe583d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6ec3a91d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xda08b78a, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xca033f13, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4b4b06dc, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1ba9ad96, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc64198d3, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb4456653, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe78284e2, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6b4b0859, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x37f940d0, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x775b5370, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x72a85b43, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x779875ab, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe41dcb24, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb9131821, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb701cace, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc7dbf2cb, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5ca3e1e9, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa6b6d8d1, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcd869e04, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x778acc3c, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdf50de60, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1310276e, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x00de7b12, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf1282803, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7de2ec76, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x658ec38a, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xfb515038, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xd4256b4b, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6d9754a4, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa584ce58, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0f3ed99e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x75fb689e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xafe53192, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [209649] → new MockPriceOracle@0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    │   └─ ← [Return] 1047 bytes of code
    ├─ [209649] → new MockPriceOracle@0x15cF58144EF33af1e14b5208015d11F9143E27b9
    │   └─ ← [Return] 1047 bytes of code
    ├─ [209649] → new MockPriceOracle@0x212224D2F2d262cd093eE13240ca4873fcCBbA3C
    │   └─ ← [Return] 1047 bytes of code
    ├─ [0] VM::addr(<pk>) [staticcall]
    │   └─ ← [Return] 0x6E9972213BF459853FA33E28Ab7219e9157C8d02
    ├─ [2320548] → new TrustedReporterAdapter@0x2a07706473244BC757E10F2a9E86fB532828afe3
    │   ├─ emit OwnershipTransferred(previousOwner: 0x0000000000000000000000000000000000000000, newOwner: 0x00000000000000000000000000000000000A11cE)
    │   ├─ emit MaxSignatureAgeUpdated(previousSeconds: 0, newSeconds: 3600)
    │   └─ ← [Return] 11214 bytes of code
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [25437] ERC1967Proxy::fallback(MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF])
    │   ├─ [24963] MarketEngineDispatcher::setRateOracle(MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF]) [delegatecall]
    │   │   ├─ emit RateOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [25460] ERC1967Proxy::fallback(MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9])
    │   ├─ [24986] MarketEngineDispatcher::setSmartDataOracle(MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9]) [delegatecall]
    │   │   ├─ emit SmartDataOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0x15cF58144EF33af1e14b5208015d11F9143E27b9])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [25436] ERC1967Proxy::fallback(MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C])
    │   ├─ [24962] MarketEngineDispatcher::setMacroOracle(MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C]) [delegatecall]
    │   │   ├─ emit MacroOracleSet(previousOracle: 0x0000000000000000000000000000000000000000, newOracle: MockPriceOracle: [0x212224D2F2d262cd093eE13240ca4873fcCBbA3C])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [47293] MockERC20::mint(0x0000000000000000000000000000000000A11ce1, 1000000000000000000000000 [1e24])
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x0000000000000000000000000000000000A11ce1, value: 1000000000000000000000000 [1e24])
    │   └─ ← [Stop]
    ├─ [25393] MockERC20::mint(0x000000000000000000000000000000000000b0b1, 1000000000000000000000000 [1e24])
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x000000000000000000000000000000000000b0b1, value: 1000000000000000000000000 [1e24])
    │   └─ ← [Stop]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [25298] MockERC20::approve(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   ├─ emit Approval(owner: 0x0000000000000000000000000000000000A11ce1, spender: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   └─ ← [Return] true
    ├─ [0] VM::prank(0x000000000000000000000000000000000000b0b1)
    │   └─ ← [Return]
    ├─ [25298] MockERC20::approve(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   ├─ emit Approval(owner: 0x000000000000000000000000000000000000b0b1, spender: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   └─ ← [Return] true
    └─ ← [Stop]

  [1382098] MarketTypeAll15Test::test_marketType_10_cascade_downward_support_breaks()
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [336801] ERC1967Proxy::fallback(UpsertTemplateParams({ slug: "mt-cascade-oil", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 8, condition: 0, thresholdRule: 0, active: true, outcomeCount: 4, absoluteThresholdValueE8: 0, rangeBoundsE8: [8000000000 [8e9], 7800000000 [7.8e9], 7500000000 [7.5e9], 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: true, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] }))
    │   ├─ [331394] MarketEngineDispatcher::fallback(UpsertTemplateParams({ slug: "mt-cascade-oil", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 8, condition: 0, thresholdRule: 0, active: true, outcomeCount: 4, absoluteThresholdValueE8: 0, rangeBoundsE8: [8000000000 [8e9], 7800000000 [7.8e9], 7500000000 [7.5e9], 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: true, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [297975] MarketEngineCoreLifecycleModule::upsertTemplate(UpsertTemplateParams({ slug: "mt-cascade-oil", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, marketType: 8, condition: 0, thresholdRule: 0, active: true, outcomeCount: 4, absoluteThresholdValueE8: 0, rangeBoundsE8: [8000000000 [8e9], 7800000000 [7.8e9], 7500000000 [7.5e9], 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: true, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   ├─ emit TemplateUpserted(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, slug: "mt-cascade-oil", marketType: 8, outcomeCount: 4, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [1770] ERC1967Proxy::fallback("mt-cascade-oil") [staticcall]
    │   ├─ [1284] MarketEngineDispatcher::templateIdFromSlug("mt-cascade-oil") [delegatecall]
    │   │   └─ ← [Return] 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860
    │   └─ ← [Return] 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860
    ├─ [28467] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860)
    │   ├─ [27993] MarketEngineDispatcher::initializeMarket(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860) [delegatecall]
    │   │   ├─ emit MarketInitialized(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [38217] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860) [staticcall]
    │   ├─ [37292] MarketEngineDispatcher::templates(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860) [delegatecall]
    │   │   └─ ← [Return] Template({ version: 1, marketType: 8, condition: 0, thresholdRule: 0, active: true, outcomeCount: 4, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, slug: "mt-cascade-oil", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, absoluteThresholdValueE8: 0, rangeBoundsE8: [8000000000 [8e9], 7800000000 [7.8e9], 7500000000 [7.5e9], 0, 0, 0, 0], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: true, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })
    │   └─ ← [Return] Template({ version: 1, marketType: 8, condition: 0, thresholdRule: 0, active: true, outcomeCount: 4, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, slug: "mt-cascade-oil", assetSymbol: "ETH", oracleFeedId: 0x0000000000000000000000000000000000000000000000000000000000000000, absoluteThresholdValueE8: 0, rangeBoundsE8: [8000000000 [8e9], 7800000000 [7.8e9], 7500000000 [7.5e9], 0, 0, 0, 0], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 1, oracleClass: 0, eventOracle: 0x2a07706473244BC757E10F2a9E86fB532828afe3, cascadeDownward: true, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })
    ├─ [0] VM::warp(1090000 [1.09e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [240583] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 1090100 [1.09e6], 1090200 [1.09e6], 1090300 [1.09e6])
    │   ├─ [240088] MarketEngineDispatcher::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 1090100 [1.09e6], 1090200 [1.09e6], 1090300 [1.09e6]) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [213370] MarketEngineCoreLifecycleModule::openEpoch(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 1090100 [1.09e6], 1090200 [1.09e6], 1090300 [1.09e6]) [delegatecall]
    │   │   │   ├─ emit EpochOpened(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, openAt: 1090100 [1.09e6], lockAt: 1090200 [1.09e6], resolveAt: 1090300 [1.09e6])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1090150 [1.09e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [275915] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 0, 60000000000000000000 [6e19])
    │   ├─ [275426] MarketEngineDispatcher::depositToSide(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 0, 60000000000000000000 [6e19]) [delegatecall]
    │   │   ├─ [33166] MockERC20::transferFrom(0x0000000000000000000000000000000000A11ce1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 60000000000000000000 [6e19])
    │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000A11ce1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 60000000000000000000 [6e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit UserEpochIndexed(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1)
    │   │   ├─ emit PositionDeposited(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1, outcome: 0, amount: 60000000000000000000 [6e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x000000000000000000000000000000000000b0b1)
    │   └─ ← [Return]
    ├─ [181815] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 1, 60000000000000000000 [6e19])
    │   ├─ [181326] MarketEngineDispatcher::depositToSide(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 1, 60000000000000000000 [6e19]) [delegatecall]
    │   │   ├─ [11266] MockERC20::transferFrom(0x000000000000000000000000000000000000b0b1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 60000000000000000000 [6e19])
    │   │   │   ├─ emit Transfer(from: 0x000000000000000000000000000000000000b0b1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 60000000000000000000 [6e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit UserEpochIndexed(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x000000000000000000000000000000000000b0b1)
    │   │   ├─ emit PositionDeposited(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x000000000000000000000000000000000000b0b1, outcome: 1, amount: 60000000000000000000 [6e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000A11ce1)
    │   └─ ← [Return]
    ├─ [61508] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 2, 60000000000000000000 [6e19])
    │   ├─ [61019] MarketEngineDispatcher::depositToSide(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 2, 60000000000000000000 [6e19]) [delegatecall]
    │   │   ├─ [4466] MockERC20::transferFrom(0x0000000000000000000000000000000000A11ce1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 60000000000000000000 [6e19])
    │   │   │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000A11ce1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 60000000000000000000 [6e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit PositionDeposited(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x0000000000000000000000000000000000A11ce1, outcome: 2, amount: 60000000000000000000 [6e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x000000000000000000000000000000000000b0b1)
    │   └─ ← [Return]
    ├─ [61508] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 3, 60000000000000000000 [6e19])
    │   ├─ [61019] MarketEngineDispatcher::depositToSide(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1, 3, 60000000000000000000 [6e19]) [delegatecall]
    │   │   ├─ [4466] MockERC20::transferFrom(0x000000000000000000000000000000000000b0b1, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 60000000000000000000 [6e19])
    │   │   │   ├─ emit Transfer(from: 0x000000000000000000000000000000000000b0b1, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 60000000000000000000 [6e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit PositionDeposited(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, user: 0x000000000000000000000000000000000000b0b1, outcome: 3, amount: 60000000000000000000 [6e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1090200 [1.09e6])
    │   └─ ← [Return]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [41937] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1)
    │   ├─ [41460] MarketEngineDispatcher::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [14750] MarketEngineCoreLifecycleModule::lockEpoch(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1) [delegatecall]
    │   │   │   ├─ emit EpochLocked(templateId: 0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, epochId: 1, checkpointAValueE8: 0, publishTime: 0)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    ├─ [0] VM::warp(1090300 [1.09e6])
    │   └─ ← [Return]
    ├─ [1825] ERC1967Proxy::fallback(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1) [staticcall]
    │   ├─ [1345] MarketEngineDispatcher::positionKey(0x65e608ecd383fc2dd6c04f87f01a5434479a7e6b0c115c58045c2fa3cea39860, 1) [delegatecall]
    │   │   └─ ← [Return] 0x6524ce47cc87ad32fa61e8c5208cdb5079259f83e08417caab515f3711cfbb6d
    │   └─ ← [Return] 0x6524ce47cc87ad32fa61e8c5208cdb5079259f83e08417caab515f3711cfbb6d
    ├─ [0] VM::sign("<pk>", 0x40c4f60f214def63acda5159876ad8b6183b909890705f6490af9bf5845f856d) [staticcall]
    │   └─ ← [Return] 28, 0x3b80d26b9d24b1981db9d2fbcba12ed689dca91e1aac6daddd68be16c625d876, 0x3e1d7425e8699ef9291f8a69070e689c95403c4a40bb266bb5f68172b5905780
    ├─ [20579] TrustedReporterAdapter::postOhlcResult(0x6524ce47cc87ad32fa61e8c5208cdb5079259f83e08417caab515f3711cfbb6d, 8200000000 [8.2e9], 7700000000 [7.7e9], 7900000000 [7.9e9], 1090300 [1.09e6], 0x03a30c5c83f84f53d375aeb9d420c63f1ba6bfb0fc8e54f6f1dc9c4653eb9b98, 0x3b80d26b9d24b1981db9d2fbcba12ed689dca91e1aac6daddd68be16c625d8763e1d7425e8699ef9291f8a69070e689c95403c4a40bb266bb5f68172b59057801c)
    │   ├─ [3000] PRECOMPILES::ecrecover(0x2c56f835688b5c70d9783d5e37606c9f3e82dfb46762642514d5ce93963732a2, 28, 26914066758700594227588149994405087195062930985187048467952122176612239530102, 28095436801611245236629640468289576419045434336238368990199172516301553817472) [staticcall]
    │   │   └─ ← [Return] 0xe6B222caAC01a1694210A41F2f08FdDd63AeC37D
    │   └─ ← [Revert] InvalidReporterSignature()
    └─ ← [Revert] InvalidReporterSignature()

Backtrace:
  at TrustedReporterAdapter.postOhlcResult
  at MarketTypeAll15Test.test_marketType_10_cascade_downward_support_breaks

Suite result: FAILED. 0 passed; 2 failed; 0 skipped; finished in 14.26ms (4.35ms CPU time)

Ran 1 test for test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryInvariants
[FAIL: invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal replay failure]
        [Sequence] (original: 3, shrunk: 3)
                sender=0x81ab276Eb588f519388125eb6eF24225F424CAb2 addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=deposit(uint256,uint256,uint256,uint256) args=[540236226398078971834273683152712487528506458041 [5.402e47], 10331401914185406687735296473954845837413765932354355735524734 [1.033e61], 4169630958367906130397537777265261241558 [4.169e39], 115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77]]
                sender=0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=lockCurrent(uint256) args=[14077 [1.407e4]]
                sender=0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=resolveCurrent(uint256,uint256) args=[1001, 1000]
 invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal() (runs: 1, calls: 1, reverts: 1)
Traces:
  [54569185] MarketEngineRoutedRecoveryInvariants::setUp()
    ├─ [787511] → new MockERC20@0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f
    │   └─ ← [Return] 3706 bytes of code
    ├─ [209649] → new MockPriceOracle@0x2e234DAe75C793f67A35089C9d99245E1C58470b
    │   └─ ← [Return] 1047 bytes of code
    ├─ [11254358] → new MarketEngineDispatcher@0xF62849F9A0B5Bf2913b396098F7c7019b51A820a
    │   ├─ emit Initialized(version: 18446744073709551615 [1.844e19])
    │   └─ ← [Return] 56069 bytes of code
    ├─ [249759] → new ERC1967Proxy@0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9
    │   ├─ emit Upgraded(implementation: MarketEngineDispatcher: [0xF62849F9A0B5Bf2913b396098F7c7019b51A820a])
    │   ├─ [191688] MarketEngineDispatcher::initialize(InitConfig({ stakeToken: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, priceOracle: 0x2e234DAe75C793f67A35089C9d99245E1C58470b, admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, worker: 0x0000000000000000000000000000000000000B0b, defaultSettlementFeeBps: 100, maxSwitchFeeBps: 500, maxOutcomes: 8, oracleKind: 0, oracleMaxDelaySeconds: 3600, oracleMaxConfidenceBps: 10000 [1e4] })) [delegatecall]
    │   │   ├─ emit ConfigInitialized(admin: 0x00000000000000000000000000000000000A11cE, treasury: 0x0000000000000000000000000000000000000FEE, workerAuthority: 0x0000000000000000000000000000000000000B0b)
    │   │   ├─ emit Initialized(version: 1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return] 158 bytes of code
    ├─ [3445642] → new MarketEngineAdminModule@0xc7183455a4C133Ae270771860664b6B7ec320bB1
    │   └─ ← [Return] 17209 bytes of code
    ├─ [5702336] → new MarketEngineViewModule@0xa0Cb889707d426A7A386870A03bc70d1b0697598
    │   └─ ← [Return] 28477 bytes of code
    ├─ [3722194] → new MarketEngineUserOpsClaimsModule@0x1d1499e622D69689cdf9004d05Ec547d650Ff211
    │   └─ ← [Return] 18590 bytes of code
    ├─ [9278232] → new MarketEngineCoreLifecycleModule@0xA4AD4f68d0b91CFD19687c881e50f3A00242828c
    │   └─ ← [Return] 46327 bytes of code
    ├─ [7944292] → new MarketEngineRollingLifecycleModule@0x03A6a84cD762D9707A21605b548aaaB891562aAb
    │   └─ ← [Return] 39669 bytes of code
    ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [24858] ERC1967Proxy::fallback(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [24384] MarketEngineDispatcher::allowModuleCodeHash(0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ emit ModuleCodeHashAllowed(codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57028] ERC1967Proxy::fallback(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   ├─ [56551] MarketEngineDispatcher::registerModule(MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], codeHash: 0x93a335b643ed5248c8c7e76d94645746073846977d742bd768412d69ca6fefb4)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [62296] ERC1967Proxy::fallback(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   ├─ [61819] MarketEngineDispatcher::registerModule(MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], codeHash: 0x2cfbd9837e3f15381d70d4c2cfd67bc342e9dd7d63485db58cba82d3336ba4b8)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [57667] ERC1967Proxy::fallback(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   ├─ [57190] MarketEngineDispatcher::registerModule(MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], codeHash: 0x6b1ea4738914f96e753cf33080ebb20096507ac08e590045f095c2c2cb3f8077)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [71484] ERC1967Proxy::fallback(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   ├─ [71007] MarketEngineDispatcher::registerModule(MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], codeHash: 0x6f167cf35344b295a7e8ee5f209cf0a6e7ab508e5330895179acf31989e7cb1d)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [67868] ERC1967Proxy::fallback(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   ├─ [67391] MarketEngineDispatcher::registerModule(MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit ModuleRegistered(module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], codeHash: 0xb887b51a839e6964ab3e1e9fd20bf8febfea85020230593eb0918151187426f1)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa676be29, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa676be29, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf0f44260, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf0f44260, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x8db50d4d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x8db50d4d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x4f6916d1, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4f6916d1, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x54977e3c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x54977e3c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x93a49e9f, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x93a49e9f, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xcf3c99bd, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcf3c99bd, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x2b0957d5, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x2b0957d5, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x7db6585d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7db6585d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xa225f18e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa225f18e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdfaa5f2e, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdfaa5f2e, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xdbb97b54, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdbb97b54, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x939cab22, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x939cab22, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xf8937fae, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf8937fae, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x23a70c21, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x23a70c21, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x74adbb70, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x74adbb70, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x0469435b, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0469435b, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x5bd55b1c, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5bd55b1c, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0xe2fe583d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe2fe583d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38185] ERC1967Proxy::fallback(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false)
    │   ├─ [37702] MarketEngineDispatcher::setSelectorModule(0x6ec3a91d, MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], false) [delegatecall]
    │   │   ├─ [421] MarketEngineAdminModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6ec3a91d, module: MarketEngineAdminModule: [0xc7183455a4C133Ae270771860664b6B7ec320bB1], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xda08b78a, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xda08b78a, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xca033f13, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xca033f13, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x4b4b06dc, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x4b4b06dc, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x1ba9ad96, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1ba9ad96, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xc64198d3, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc64198d3, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xb4456653, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb4456653, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe78284e2, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe78284e2, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x6b4b0859, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6b4b0859, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x37f940d0, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x37f940d0, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x775b5370, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x775b5370, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x72a85b43, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x72a85b43, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0x779875ab, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x779875ab, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [43455] ERC1967Proxy::fallback(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false)
    │   ├─ [42972] MarketEngineDispatcher::setSelectorModule(0xe41dcb24, MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], false) [delegatecall]
    │   │   ├─ [466] MarketEngineViewModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xe41dcb24, module: MarketEngineViewModule: [0xa0Cb889707d426A7A386870A03bc70d1b0697598], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb9131821, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb9131821, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xb701cace, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xb701cace, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xc7dbf2cb, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xc7dbf2cb, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0x5ca3e1e9, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x5ca3e1e9, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [38825] ERC1967Proxy::fallback(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false)
    │   ├─ [38342] MarketEngineDispatcher::setSelectorModule(0xa6b6d8d1, MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], false) [delegatecall]
    │   │   ├─ [444] MarketEngineUserOpsClaimsModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa6b6d8d1, module: MarketEngineUserOpsClaimsModule: [0x1d1499e622D69689cdf9004d05Ec547d650Ff211], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xcd869e04, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xcd869e04, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x778acc3c, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x778acc3c, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xdf50de60, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xdf50de60, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x1310276e, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x1310276e, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x00de7b12, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x00de7b12, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0xf1282803, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xf1282803, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x7de2ec76, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x7de2ec76, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [52645] ERC1967Proxy::fallback(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false)
    │   ├─ [52162] MarketEngineDispatcher::setSelectorModule(0x658ec38a, MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], false) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x658ec38a, module: MarketEngineCoreLifecycleModule: [0xA4AD4f68d0b91CFD19687c881e50f3A00242828c], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xfb515038, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xfb515038, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xd4256b4b, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xd4256b4b, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x6d9754a4, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x6d9754a4, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xa584ce58, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xa584ce58, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x0f3ed99e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x0f3ed99e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0x75fb689e, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0x75fb689e, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [49027] ERC1967Proxy::fallback(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false)
    │   ├─ [48544] MarketEngineDispatcher::setSelectorModule(0xafe53192, MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], false) [delegatecall]
    │   │   ├─ [377] MarketEngineRollingLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ emit SelectorModuleSet(selector: 0xafe53192, module: MarketEngineRollingLifecycleModule: [0x03A6a84cD762D9707A21605b548aaaB891562aAb], immutableSelector: false)
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    ├─ [1770] ERC1967Proxy::fallback("inv-routed-a") [staticcall]
    │   ├─ [1284] MarketEngineDispatcher::templateIdFromSlug("inv-routed-a") [delegatecall]
    │   │   └─ ← [Return] 0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2
    │   └─ ← [Return] 0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2
    ├─ [1770] ERC1967Proxy::fallback("inv-routed-b") [staticcall]
    │   ├─ [1284] MarketEngineDispatcher::templateIdFromSlug("inv-routed-b") [delegatecall]
    │   │   └─ ← [Return] 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a
    │   └─ ← [Return] 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a
    ├─ [1250240] → new MockPartialYieldRouter@0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF
    │   └─ ← [Return] 6130 bytes of code
    ├─ [5941285] → new MarketEngineRoutedRecoveryHandler@0x15cF58144EF33af1e14b5208015d11F9143E27b9
    │   └─ ← [Return] 27877 bytes of code
    ├─ [1056819] MarketEngineRoutedRecoveryHandler::bootstrap()
    │   ├─ [0] VM::startPrank(0x00000000000000000000000000000000000A11cE)
    │   │   └─ ← [Return]
    │   ├─ [253971] ERC1967Proxy::fallback(UpsertTemplateParams({ slug: "inv-routed-a", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] }))
    │   │   ├─ [253064] MarketEngineDispatcher::fallback(UpsertTemplateParams({ slug: "inv-routed-a", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   │   ├─ [228145] MarketEngineCoreLifecycleModule::upsertTemplate(UpsertTemplateParams({ slug: "inv-routed-a", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   │   ├─ emit TemplateUpserted(templateId: 0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, slug: "inv-routed-a", marketType: 1, outcomeCount: 2, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   └─ ← [Return]
    │   ├─ [28467] ERC1967Proxy::fallback(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2)
    │   │   ├─ [27993] MarketEngineDispatcher::initializeMarket(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2) [delegatecall]
    │   │   │   ├─ emit MarketInitialized(templateId: 0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   ├─ [253971] ERC1967Proxy::fallback(UpsertTemplateParams({ slug: "inv-routed-b", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] }))
    │   │   ├─ [253064] MarketEngineDispatcher::fallback(UpsertTemplateParams({ slug: "inv-routed-b", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   │   ├─ [228145] MarketEngineCoreLifecycleModule::upsertTemplate(UpsertTemplateParams({ slug: "inv-routed-b", assetSymbol: "ETH", oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, marketType: 1, condition: 0, thresholdRule: 1, active: true, outcomeCount: 2, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], switchFeeBps: 100, settlementFeeBps: 100, allowMultiSidePositions: true, executionMode: 0, rollingIntervalSeconds: 0, rollingBufferSeconds: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, templateOracleKind: 0, oracleClass: 0, eventOracle: 0x0000000000000000000000000000000000000000, cascadeDownward: false, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0] })) [delegatecall]
    │   │   │   │   ├─ emit TemplateUpserted(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, slug: "inv-routed-b", marketType: 1, outcomeCount: 2, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0)
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   └─ ← [Return]
    │   ├─ [28467] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a)
    │   │   ├─ [27993] MarketEngineDispatcher::initializeMarket(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a) [delegatecall]
    │   │   │   ├─ emit MarketInitialized(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   ├─ [53989] ERC1967Proxy::fallback(MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], 0)
    │   │   ├─ [53512] MarketEngineDispatcher::setYieldRouter(MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], 0) [delegatecall]
    │   │   │   ├─ [25298] MockERC20::approve(MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   │   │   │   ├─ emit Approval(owner: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], spender: MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   │   │   │   └─ ← [Return] true
    │   │   │   ├─ emit YieldRouterSet(oldRouter: 0x0000000000000000000000000000000000000000, newRouter: MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], yieldFeeBps: 0)
    │   │   │   ├─ emit YieldRouterFailureStateReset()
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   ├─ [0] VM::stopPrank()
    │   │   └─ ← [Return]
    │   ├─ [0] VM::warp(1000000 [1e6])
    │   │   └─ ← [Return]
    │   ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   │   └─ ← [Return]
    │   ├─ [181700] ERC1967Proxy::fallback(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, 1, 1000000 [1e6], 1000010 [1e6], 1000020 [1e6])
    │   │   ├─ [181205] MarketEngineDispatcher::fallback(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, 1, 1000000 [1e6], 1000010 [1e6], 1000020 [1e6]) [delegatecall]
    │   │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   │   ├─ [156487] MarketEngineCoreLifecycleModule::openEpoch(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, 1, 1000000 [1e6], 1000010 [1e6], 1000020 [1e6]) [delegatecall]
    │   │   │   │   ├─ emit EpochOpened(templateId: 0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, epochId: 1, openAt: 1000000 [1e6], lockAt: 1000010 [1e6], resolveAt: 1000020 [1e6])
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   └─ ← [Return]
    │   ├─ [0] VM::warp(1000100 [1e6])
    │   │   └─ ← [Return]
    │   ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   │   └─ ← [Return]
    │   ├─ [181700] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1, 1000100 [1e6], 1000110 [1e6], 1000120 [1e6])
    │   │   ├─ [181205] MarketEngineDispatcher::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1, 1000100 [1e6], 1000110 [1e6], 1000120 [1e6]) [delegatecall]
    │   │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   │   ├─ [156487] MarketEngineCoreLifecycleModule::openEpoch(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1, 1000100 [1e6], 1000110 [1e6], 1000120 [1e6]) [delegatecall]
    │   │   │   │   ├─ emit EpochOpened(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6])
    │   │   │   │   └─ ← [Stop]
    │   │   │   └─ ← [Return]
    │   │   └─ ← [Return]
    │   └─ ← [Stop]
    └─ ← [Stop]

  [751940] MarketEngineRoutedRecoveryHandler::deposit(540236226398078971834273683152712487528506458041 [5.402e47], 10331401914185406687735296473954845837413765932354355735524734 [1.033e61], 4169630958367906130397537777265261241558 [4.169e39], 115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77])
    ├─ [235515] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [staticcall]
    │   ├─ [229636] MarketEngineDispatcher::epochs(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 0, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 0, outcomePools: [0, 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 0, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 0, outcomePools: [0, 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    ├─ [3081] ERC1967Proxy::fallback() [staticcall]
    │   ├─ [2607] MarketEngineDispatcher::globalPaused() [delegatecall]
    │   │   └─ ← [Return] false
    │   └─ ← [Return] false
    ├─ [47293] MockERC20::mint(0x000000000000000000000000000000000000cafE, 49999999999999999998 [4.999e19])
    │   ├─ emit Transfer(from: 0x0000000000000000000000000000000000000000, to: 0x000000000000000000000000000000000000cafE, value: 49999999999999999998 [4.999e19])
    │   └─ ← [Stop]
    ├─ [0] VM::startPrank(0x000000000000000000000000000000000000cafE)
    │   └─ ← [Return]
    ├─ [25298] MockERC20::approve(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   ├─ emit Approval(owner: 0x000000000000000000000000000000000000cafE, spender: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 115792089237316195423570985008687907853269984665640564039457584007913129639935 [1.157e77])
    │   └─ ← [Return] true
    ├─ [372788] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1, 0, 49999999999999999998 [4.999e19])
    │   ├─ [372299] MarketEngineDispatcher::depositToSide(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1, 0, 49999999999999999998 [4.999e19]) [delegatecall]
    │   │   ├─ [26366] MockERC20::transferFrom(0x000000000000000000000000000000000000cafE, ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 49999999999999999998 [4.999e19])
    │   │   │   ├─ emit Transfer(from: 0x000000000000000000000000000000000000cafE, to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 49999999999999999998 [4.999e19])
    │   │   │   └─ ← [Return] true
    │   │   ├─ emit UserEpochIndexed(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, user: 0x000000000000000000000000000000000000cafE)
    │   │   ├─ [30147] MockPartialYieldRouter::depositScaled(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 47499999999999999998 [4.749e19])
    │   │   │   ├─ [28366] MockERC20::transferFrom(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], 47499999999999999998 [4.749e19])
    │   │   │   │   ├─ emit Transfer(from: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], to: MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], value: 47499999999999999998 [4.749e19])
    │   │   │   │   └─ ← [Return] true
    │   │   │   └─ ← [Return] 47499999999999999998 [4.749e19]
    │   │   ├─ emit PositionDeposited(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, user: 0x000000000000000000000000000000000000cafE, outcome: 0, amount: 49999999999999999998 [4.999e19])
    │   │   └─ ← [Stop]
    │   └─ ← [Return]
    ├─ [0] VM::stopPrank()
    │   └─ ← [Return]
    └─ ← [Stop]

  [409174] MarketEngineRoutedRecoveryHandler::lockCurrent(14077 [1.407e4])
    ├─ [235515] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [staticcall]
    │   ├─ [229636] MarketEngineDispatcher::epochs(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 47499999999999999998 [4.749e19], templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 47499999999999999998 [4.749e19], templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    ├─ [3081] ERC1967Proxy::fallback() [staticcall]
    │   ├─ [2607] MarketEngineDispatcher::globalPaused() [delegatecall]
    │   │   └─ ← [Return] false
    │   └─ ← [Return] false
    ├─ [0] VM::warp(1000111 [1e6])
    │   └─ ← [Return]
    ├─ [47587] MockPriceOracle::set(0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, 10000000000 [1e10], 1000111 [1e6], 0)
    │   └─ ← [Stop]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [58037] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1)
    │   ├─ [57560] MarketEngineDispatcher::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [24350] MarketEngineCoreLifecycleModule::lockEpoch(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   │   ├─ emit EpochLocked(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, checkpointAValueE8: 0, publishTime: 0)
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    └─ ← [Stop]

  [778794] MarketEngineRoutedRecoveryHandler::resolveCurrent(1001, 1000)
    ├─ [235515] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [staticcall]
    │   ├─ [229636] MarketEngineDispatcher::epochs(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   └─ ← [Return] Epoch({ version: 1, status: 2, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 1000111 [1e6], resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 47499999999999999998 [4.749e19], templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    │   └─ ← [Return] Epoch({ version: 1, status: 2, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 1000111 [1e6], resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 47499999999999999998 [4.749e19], templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    ├─ [0] VM::warp(1000121 [1e6])
    │   └─ ← [Return]
    ├─ [13387] MockPriceOracle::set(0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, 20000000000 [2e10], 1000121 [1e6], 0)
    │   └─ ← [Stop]
    ├─ [0] VM::prank(0x0000000000000000000000000000000000000B0b)
    │   └─ ← [Return]
    ├─ [465406] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1)
    │   ├─ [464929] MarketEngineDispatcher::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   ├─ [399] MarketEngineCoreLifecycleModule::marketEngineStorageCompatibility() [staticcall]
    │   │   │   └─ ← [Return] 0x9c93d6674956fa52bc53619b0ffc7c148819c33a80cfe5e444a5a9ed1e7d9d27
    │   │   ├─ [431700] MarketEngineCoreLifecycleModule::resolveEpoch(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   │   ├─ [146] MockPriceOracle::getNormalizedPriceWithRoundId(0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, 3600, 1000121 [1e6]) [staticcall]
    │   │   │   │   └─ ← [Revert] unrecognized function selector 0x5f93e6c0 for contract 0x2e234DAe75C793f67A35089C9d99245E1C58470b, which has no fallback function.
    │   │   │   ├─ [1732] MockPriceOracle::getNormalizedPrice(0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, 3600, 1000121 [1e6]) [staticcall]
    │   │   │   │   └─ ← [Return] 20000000000 [2e10], 1000121 [1e6], 0
    │   │   │   ├─ [2851] MockERC20::balanceOf(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]) [staticcall]
    │   │   │   │   └─ ← [Return] 2500000000000000000 [2.5e18]
    │   │   │   ├─ [15874] MockPartialYieldRouter::withdrawScaled(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 47499999999999999998 [4.749e19])
    │   │   │   │   ├─ [11450] MockERC20::transfer(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], 47499999999999999998 [4.749e19])
    │   │   │   │   │   ├─ emit Transfer(from: MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], to: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], value: 47499999999999999998 [4.749e19])
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   └─ ← [Return] 47499999999999999998 [4.749e19]
    │   │   │   ├─ [851] MockERC20::balanceOf(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]) [staticcall]
    │   │   │   │   └─ ← [Return] 49999999999999999998 [4.999e19]
    │   │   │   ├─ emit EpochResolved(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, winningMask: 1, claimLiabilityTotal: 49999999999999999998 [4.999e19], settlementFeeTotal: 0, refundMode: false)
    │   │   │   ├─ emit EpochResolvedV2(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, oracleRoundId: 0, checkpointBValueE8: 20000000000 [2e10], publishTime: 1000121 [1e6])
    │   │   │   ├─ [851] MockERC20::balanceOf(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]) [staticcall]
    │   │   │   │   └─ ← [Return] 49999999999999999998 [4.999e19]
    │   │   │   ├─ [8424] MockPartialYieldRouter::depositDetailed(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 49999999999999999998 [4.999e19])
    │   │   │   │   ├─ [6466] MockERC20::transferFrom(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], 49999999999999999998 [4.999e19])
    │   │   │   │   │   ├─ emit Transfer(from: ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9], to: MockPartialYieldRouter: [0xD6BbDE9174b1CdAa358d2Cf4D57D1a9F7178FBfF], value: 49999999999999999998 [4.999e19])
    │   │   │   │   │   └─ ← [Return] true
    │   │   │   │   └─ ← [Return] 49999999999999999998 [4.999e19], 49999999999999999998 [4.999e19]
    │   │   │   ├─ [851] MockERC20::balanceOf(ERC1967Proxy: [0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9]) [staticcall]
    │   │   │   │   └─ ← [Return] 0
    │   │   │   ├─ emit EpochSettledClaimsRouted(templateId: 0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, epochId: 1, baseAmount: 49999999999999999998 [4.999e19], principalAmount: 49999999999999999998 [4.999e19], attributionUnits: 49999999999999999998 [4.999e19])
    │   │   │   └─ ← [Stop]
    │   │   └─ ← [Return]
    │   └─ ← [Return]
    └─ ← [Stop]

  [577052] MarketEngineRoutedRecoveryInvariants::invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal()
    ├─ [2898] MarketEngineRoutedRecoveryHandler::currentEpochIds(0) [staticcall]
    │   └─ ← [Return] 1
    ├─ [235515] ERC1967Proxy::fallback(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, 1) [staticcall]
    │   ├─ [229636] MarketEngineDispatcher::epochs(0x0f973499d10860d857908312aad4ad238d749ad535549e7a4cac3e00ec974fa2, 1) [delegatecall]
    │   │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 0, timing: MarketTiming({ openAt: 1000000 [1e6], lockAt: 1000010 [1e6], resolveAt: 1000020 [1e6] }), createdAt: 1000000 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 0, outcomePools: [0, 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    │   └─ ← [Return] Epoch({ version: 1, status: 1, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: false, exists: true, epochId: 1, totalPositions: 0, timing: MarketTiming({ openAt: 1000000 [1e6], lockAt: 1000010 [1e6], resolveAt: 1000020 [1e6] }), createdAt: 1000000 [1e6], lockedAt: 0, resolvedAt: 0, oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 0, totalPool: 0, outcomePools: [0, 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 0, totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 0, winningPoolTotal: 0, routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    ├─ [898] MarketEngineRoutedRecoveryHandler::currentEpochIds(0) [staticcall]
    │   └─ ← [Return] 1
    ├─ [948] MarketEngineRoutedRecoveryHandler::currentEpochIds(1) [staticcall]
    │   └─ ← [Return] 1
    ├─ [231015] ERC1967Proxy::fallback(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [staticcall]
    │   ├─ [229636] MarketEngineDispatcher::epochs(0x9aaf49b53bbdb16e938c975f8ce8b3b4b2ff7b8acdccf4c7a7b4dc67e071d05a, 1) [delegatecall]
    │   │   └─ ← [Return] Epoch({ version: 1, status: 3, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: true, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 1000111 [1e6], resolvedAt: 1000121 [1e6], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 20000000000 [2e10], confidenceE8: 0, publishTime: 1000121 [1e6], written: true }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 1, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 49999999999999999998 [4.999e19], totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 49999999999999999998 [4.999e19], winningPoolTotal: 49999999999999999998 [4.999e19], routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    │   └─ ← [Return] Epoch({ version: 1, status: 3, cancelReason: 0, outcomeCount: 2, marketType: 1, condition: 0, switchFeeBps: 100, settlementFeeBps: 100, equalPriceVoids: true, feeOnLosingPool: true, allowMultiSidePositions: true, refundMode: false, claimable: true, exists: true, epochId: 1, totalPositions: 1, timing: MarketTiming({ openAt: 1000100 [1e6], lockAt: 1000110 [1e6], resolveAt: 1000120 [1e6] }), createdAt: 1000100 [1e6], lockedAt: 1000111 [1e6], resolvedAt: 1000121 [1e6], oracleMaxDelaySeconds: 0, oracleMaxConfidenceBps: 0, checkpointA: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB: OracleCheckpoint({ valueE8: 20000000000 [2e10], confidenceE8: 0, publishTime: 1000121 [1e6], written: true }), oracleFeedId: 0x4258863e2d81c316e4a4dd381c3c50f57f933be22afba98b4485a605da0f7811, absoluteThresholdValueE8: 10000000000 [1e10], rangeBoundsE8: [0, 0, 0, 0, 0, 0, 0], winningOutcomeMask: 1, totalPool: 49999999999999999998 [4.999e19], outcomePools: [49999999999999999998 [4.999e19], 0, 0, 0, 0, 0, 0, 0], switchFeeTotal: 0, settlementFeeTotal: 0, claimLiabilityTotal: 49999999999999999998 [4.999e19], totalRefundLiability: 0, claimedTotal: 0, remainingWinningStake: 49999999999999999998 [4.999e19], winningPoolTotal: 49999999999999999998 [4.999e19], routedPrincipal: 0, templateOracleKind: 0, eventOracle: 0x0000000000000000000000000000000000000000, anchorPriceE8: 0, velocityBoundsE4: [0, 0, 0, 0, 0, 0, 0], ladderBoundsE8: [0, 0, 0, 0, 0, 0, 0], ladderPayoutWeightsBps: [0, 0, 0, 0, 0, 0, 0, 0], oracleFeedIdB: 0x0000000000000000000000000000000000000000000000000000000000000000, spreadToleranceBps: 0, compositeFeedIds: [0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000, 0x0000000000000000000000000000000000000000000000000000000000000000], compositeConditions: [0, 0, 0, 0], compositeFeedCount: 0, compositeLogic: 0, compositeAbsoluteThresholdsE8: [0, 0, 0, 0], oracleClass: 0, cascadeDownward: false, checkpointA_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), checkpointB_B: OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), compositeCheckpointsA: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], compositeCheckpointsB: [OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false }), OracleCheckpoint({ valueE8: 0, confidenceE8: 0, publishTime: 0, written: false })], epochHighE8: 0, epochLowE8: 0, ohlcWritten: false })
    ├─ [948] MarketEngineRoutedRecoveryHandler::currentEpochIds(1) [staticcall]
    │   └─ ← [Return] 1
    ├─ [3031] ERC1967Proxy::fallback() [staticcall]
    │   ├─ [2557] MarketEngineDispatcher::totalRoutedPrincipal() [delegatecall]
    │   │   └─ ← [Return] 49999999999999999998 [4.999e19]
    │   └─ ← [Return] 49999999999999999998 [4.999e19]
    ├─ [0] VM::assertEq(49999999999999999998 [4.999e19], 0, "global routed principal mismatch") [staticcall]
    │   └─ ← [Revert] global routed principal mismatch: 49999999999999999998 != 0
    └─ ← [Revert] global routed principal mismatch: 49999999999999999998 != 0

Suite result: FAILED. 0 passed; 1 failed; 0 skipped; finished in 10.33s (10.31s CPU time)

Ran 2 test suites in 10.34s (10.34s CPU time): 0 tests passed, 3 failed, 0 skipped (3 total tests)

Failing tests:
Encountered 1 failing test in test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryInvariants
[FAIL: invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal replay failure]
        [Sequence] (original: 3, shrunk: 3)
                sender=0x81ab276Eb588f519388125eb6eF24225F424CAb2 addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=deposit(uint256,uint256,uint256,uint256) args=[540236226398078971834273683152712487528506458041 [5.402e47], 10331401914185406687735296473954845837413765932354355735524734 [1.033e61], 4169630958367906130397537777265261241558 [4.169e39], 115792089237316195423570985008687907853269984665640564039457584007913129639933 [1.157e77]]
                sender=0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=lockCurrent(uint256) args=[14077 [1.407e4]]
                sender=0x64c911996D3c6aC71f9b455B1E8E7266BcbD848F addr=[test/invariants/MarketEngineRoutedRecoveryInvariants.t.sol:MarketEngineRoutedRecoveryHandler]0x15cF58144EF33af1e14b5208015d11F9143E27b9 calldata=resolveCurrent(uint256,uint256) args=[1001, 1000]
 invariant_totalRoutedPrincipal_matches_sum_of_epoch_routed_principal() (runs: 1, calls: 1, reverts: 1)

Encountered 2 failing tests in test/markettype/MarketTypeAll15.t.sol:MarketTypeAll15Test
[FAIL: InvalidReporterSignature()] test_marketType_09_corridor_stablecoin_with_tro_ohlc() (gas: 1235631)
[FAIL: InvalidReporterSignature()] test_marketType_10_cascade_downward_support_breaks() (gas: 1382098)

Encountered a total of 3 failing tests, 0 tests succeeded

Tip: Run `forge test --rerun` to retry only the 3 failed tests