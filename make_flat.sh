
#!/usr/bin/env bash
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloPresale.sol --out flat_MenloPresale.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MenloTokenSale.sol --out flat_MenloTokenSale.sol
solidity_flattener --solc-paths=zeppelin-solidity=$(pwd)/node_modules/zeppelin-solidity/ contracts/MET.sol --out flat_MET.sol
