
#!/usr/bin/env bash
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloToken.sol --out 1_MenloToken.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloTokenTimelock.sol --out 2_MenloTokenTimelock.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloTokenPresale.sol --out 3_MenloTokenPresale.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloTokenSale.sol --out 4_MenloTokenSale.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloTokenVesting.sol --out 5_MenloTokenVesting.sol
