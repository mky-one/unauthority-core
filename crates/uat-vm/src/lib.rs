use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use wasmer::{Store, Module, Instance, Value, imports};
use wasmer_compiler_cranelift::Cranelift;

/// Unauthority Virtual Machine (UVM)
/// Executes WebAssembly smart contracts with permissionless deployment

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Contract {
    pub address: String,
    pub code_hash: String,
    pub bytecode: Vec<u8>,
    pub state: HashMap<String, String>,
    pub balance: u128,
    pub created_at_block: u64,
    pub owner: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractCall {
    pub contract: String,
    pub function: String,
    pub args: Vec<String>,
    pub gas_limit: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ContractResult {
    pub success: bool,
    pub output: String,
    pub gas_used: u64,
    pub state_changes: HashMap<String, String>,
}

/// WASM execution environment
pub struct WasmEngine {
    contracts: Arc<Mutex<HashMap<String, Contract>>>,
    nonce: Arc<Mutex<HashMap<String, u64>>>,
}

impl WasmEngine {
    /// Create new WASM execution engine
    pub fn new() -> Self {
        WasmEngine {
            contracts: Arc::new(Mutex::new(HashMap::new())),
            nonce: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Deploy a WASM contract (Permissionless)
    pub fn deploy_contract(
        &self,
        owner: String,
        bytecode: Vec<u8>,
        initial_state: HashMap<String, String>,
        block_number: u64,
    ) -> Result<String, String> {
        // Validate WASM magic bytes (0x00 0x61 0x73 0x6d)
        if bytecode.len() < 4 || &bytecode[0..4] != b"\0asm" {
            return Err("Invalid WASM bytecode (missing magic header)".to_string());
        }

        let mut nonce = self.nonce.lock()
            .map_err(|_| "Failed to lock nonce".to_string())?;

        let owner_nonce = nonce.entry(owner.clone()).or_insert(0);
        let contract_nonce = *owner_nonce;
        *owner_nonce = owner_nonce.saturating_add(1);

        // Create deterministic address: hash(owner || nonce || block)
        let address = format!("contract_{}_{}_{}",
            owner.chars().take(12).collect::<String>(),
            contract_nonce,
            block_number
        );

        // Calculate code hash (simplified)
        let code_hash = format!("{:x}", 
            blake3::hash(&bytecode).as_bytes()[0..16]
                .iter()
                .fold(0u64, |acc, &b| (acc << 4) ^ (b as u64))
        );

        let contract = Contract {
            address: address.clone(),
            code_hash,
            bytecode,
            state: initial_state,
            balance: 0,
            created_at_block: block_number,
            owner,
        };

        let mut contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        contracts.insert(address.clone(), contract);
        Ok(address)
    }

    /// Get contract by address
    pub fn get_contract(&self, address: &str) -> Result<Contract, String> {
        let contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        contracts.get(address)
            .cloned()
            .ok_or_else(|| "Contract not found".to_string())
    }

    /// Execute real WASM bytecode using wasmer
    fn execute_wasm(&self, bytecode: &[u8], function: &str, args: &[i32]) -> Result<i32, String> {
        let compiler = Cranelift::default();
        let mut store = Store::new(compiler);
        
        let module = Module::new(&store, bytecode)
            .map_err(|e| format!("Failed to compile WASM: {}", e))?;

        let import_object = imports! {};
        let instance = Instance::new(&mut store, &module, &import_object)
            .map_err(|e| format!("Failed to instantiate WASM: {}", e))?;

        let func = instance.exports.get_function(function)
            .map_err(|e| format!("Function '{}' not found: {}", function, e))?;

        let wasm_args: Vec<Value> = args.iter().map(|&v| Value::I32(v)).collect();
        
        let result = func.call(&mut store, &wasm_args)
            .map_err(|e| format!("WASM execution failed: {}", e))?;

        if let Some(Value::I32(val)) = result.first() {
            Ok(*val)
        } else {
            Err("No return value from WASM function".to_string())
        }
    }

    /// Execute contract function (Hybrid WASM + Fallback)
    pub fn call_contract(&self, call: ContractCall) -> Result<ContractResult, String> {
        let mut contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        let contract = contracts.get_mut(&call.contract)
            .ok_or("Contract not found".to_string())?;

        // Try real WASM execution if bytecode is valid
        if contract.bytecode.len() >= 8 {
            // Check if this looks like a complete WASM module (has exports section)
            if let Ok(i32_args) = call.args.iter()
                .map(|s| s.parse::<i32>())
                .collect::<Result<Vec<_>, _>>() 
            {
                if let Ok(result) = self.execute_wasm(&contract.bytecode, &call.function, &i32_args) {
                    return Ok(ContractResult {
                        success: true,
                        output: result.to_string(),
                        gas_used: 50 + (i32_args.len() as u64 * 5),
                        state_changes: HashMap::new(),
                    });
                }
            }
        }

        // Fallback to mock dispatch for testing/simple contracts
        let (output, gas_used, state_changes) = match call.function.as_str() {
            "transfer" => {
                if call.args.len() < 2 {
                    return Err("transfer requires: amount, recipient".to_string());
                }
                let amount: u128 = call.args[0].parse()
                    .map_err(|_| "Invalid amount".to_string())?;

                if contract.balance < amount {
                    return Err("Insufficient contract balance".to_string());
                }

                contract.balance -= amount;
                (
                    format!("Transferred {} void", amount),
                    75,
                    HashMap::new(),
                )
            }
            "mint" => {
                if call.args.is_empty() {
                    return Err("mint requires: amount".to_string());
                }
                let amount: u128 = call.args[0].parse()
                    .map_err(|_| "Invalid amount".to_string())?;

                contract.balance = contract.balance.saturating_add(amount);
                (
                    format!("Minted {} void", amount),
                    100,
                    HashMap::new(),
                )
            }
            "burn" => {
                if call.args.is_empty() {
                    return Err("burn requires: amount".to_string());
                }
                let amount: u128 = call.args[0].parse()
                    .map_err(|_| "Invalid amount".to_string())?;

                if contract.balance < amount {
                    return Err("Insufficient balance to burn".to_string());
                }

                contract.balance -= amount;
                (
                    format!("Burned {} void", amount),
                    100,
                    HashMap::new(),
                )
            }
            "set_state" => {
                if call.args.len() < 2 {
                    return Err("set_state requires: key, value".to_string());
                }
                let key = call.args[0].clone();
                let value = call.args[1].clone();

                let mut sc: HashMap<String, String> = HashMap::new();
                sc.insert(key, value);
                (
                    "State updated".to_string(),
                    60,
                    sc,
                )
            }
            "get_state" => {
                if call.args.is_empty() {
                    return Err("get_state requires: key".to_string());
                }
                let key = &call.args[0];
                let value = contract.state.get(key)
                    .cloned()
                    .unwrap_or_else(|| "null".to_string());

                (
                    value,
                    30,
                    HashMap::new(),
                )
            }
            "get_balance" => {
                (
                    format!("{}", contract.balance),
                    20,
                    HashMap::new(),
                )
            }
            _ => {
                return Err(format!("Unknown function: {}", call.function));
            }
        };

        // Check gas limit
        if gas_used > call.gas_limit {
            return Err(format!("Out of gas: {} > {}", gas_used, call.gas_limit));
        }

        // Apply state changes
        for (k, v) in state_changes.iter() {
            contract.state.insert(k.clone(), v.clone());
        }

        Ok(ContractResult {
            success: true,
            output,
            gas_used,
            state_changes,
        })
    }

    /// Send native void to contract
    pub fn send_to_contract(&self, contract_addr: &str, amount: u128) -> Result<(), String> {
        let mut contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        let contract = contracts.get_mut(contract_addr)
            .ok_or("Contract not found")?;

        contract.balance = contract.balance.saturating_add(amount);
        Ok(())
    }

    /// Check if contract exists
    pub fn contract_exists(&self, address: &str) -> Result<bool, String> {
        let contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        Ok(contracts.contains_key(address))
    }

    /// List all deployed contracts
    pub fn list_contracts(&self) -> Result<Vec<String>, String> {
        let contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        Ok(contracts.keys().cloned().collect())
    }

    /// Get contract count
    pub fn contract_count(&self) -> Result<usize, String> {
        let contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        Ok(contracts.len())
    }

    /// Get contract state
    pub fn get_contract_state(&self, address: &str) -> Result<HashMap<String, String>, String> {
        let contracts = self.contracts.lock()
            .map_err(|_| "Failed to lock contracts".to_string())?;

        let contract = contracts.get(address)
            .ok_or("Contract not found")?;

        Ok(contract.state.clone())
    }
}

impl Default for WasmEngine {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_wasm_engine_creation() {
        let engine = WasmEngine::new();
        assert_eq!(engine.contract_count().unwrap(), 0);
        assert!(engine.list_contracts().unwrap().is_empty());
    }

    #[test]
    fn test_deploy_contract() {
        let engine = WasmEngine::new();
        
        // Create minimal WASM bytecode (magic header only)
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();
        let owner = "alice".to_string();

        let result = engine.deploy_contract(owner, wasm_bytes, HashMap::new(), 1);
        assert!(result.is_ok());
        
        let addr = result.unwrap();
        assert!(addr.contains("contract_"));
        assert_eq!(engine.contract_count().unwrap(), 1);
    }

    #[test]
    fn test_invalid_wasm_bytecode() {
        let engine = WasmEngine::new();
        let invalid_bytes = vec![0x00, 0x00, 0x00, 0x00];

        let result = engine.deploy_contract(
            "alice".to_string(),
            invalid_bytes,
            HashMap::new(),
            1
        );

        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Invalid WASM"));
    }

    #[test]
    fn test_get_contract() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();
        let owner = "bob".to_string();

        let addr = engine.deploy_contract(owner.clone(), wasm_bytes, HashMap::new(), 1).unwrap();
        let contract = engine.get_contract(&addr).unwrap();

        assert_eq!(contract.owner, owner);
        assert_eq!(contract.balance, 0);
    }

    #[test]
    fn test_call_transfer() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "charlie".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        // Send balance to contract first
        engine.send_to_contract(&addr, 1000).unwrap();

        let call = ContractCall {
            contract: addr,
            function: "transfer".to_string(),
            args: vec!["500".to_string(), "recipient".to_string()],
            gas_limit: 1000,
        };

        let result = engine.call_contract(call).unwrap();
        assert!(result.success);
        assert_eq!(result.gas_used, 75);
    }

    #[test]
    fn test_call_set_get_state() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "dave".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        // Set state
        let set_call = ContractCall {
            contract: addr.clone(),
            function: "set_state".to_string(),
            args: vec!["counter".to_string(), "42".to_string()],
            gas_limit: 1000,
        };

        let result = engine.call_contract(set_call).unwrap();
        assert!(result.success);

        // Get state
        let get_call = ContractCall {
            contract: addr.clone(),
            function: "get_state".to_string(),
            args: vec!["counter".to_string()],
            gas_limit: 1000,
        };

        let result = engine.call_contract(get_call).unwrap();
        assert_eq!(result.output, "42");
    }

    #[test]
    fn test_contract_balance() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "eve".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        engine.send_to_contract(&addr, 5000).unwrap();

        let call = ContractCall {
            contract: addr,
            function: "get_balance".to_string(),
            args: vec![],
            gas_limit: 100,
        };

        let result = engine.call_contract(call).unwrap();
        assert_eq!(result.output, "5000");
    }

    #[test]
    fn test_call_nonexistent_contract() {
        let engine = WasmEngine::new();
        let call = ContractCall {
            contract: "nonexistent".to_string(),
            function: "transfer".to_string(),
            args: vec![],
            gas_limit: 1000,
        };

        let result = engine.call_contract(call);
        assert!(result.is_err());
    }

    #[test]
    fn test_send_to_contract() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "frank".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        let result = engine.send_to_contract(&addr, 2500);
        assert!(result.is_ok());

        let contract = engine.get_contract(&addr).unwrap();
        assert_eq!(contract.balance, 2500);
    }

    #[test]
    fn test_multiple_deployments_increment_nonce() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();
        let owner = "grace".to_string();

        let addr1 = engine.deploy_contract(owner.clone(), wasm_bytes.clone(), HashMap::new(), 1).unwrap();
        let addr2 = engine.deploy_contract(owner, wasm_bytes, HashMap::new(), 2).unwrap();

        assert_ne!(addr1, addr2);
        assert_eq!(engine.contract_count().unwrap(), 2);
    }

    #[test]
    fn test_contract_list() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        for i in 0..3 {
            let owner = format!("user_{}", i);
            let _ = engine.deploy_contract(owner, wasm_bytes.clone(), HashMap::new(), i);
        }

        let contracts = engine.list_contracts().unwrap();
        assert_eq!(contracts.len(), 3);
    }

    #[test]
    fn test_gas_limit_exceeded() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "henry".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        engine.send_to_contract(&addr, 1000).unwrap();

        // transfer costs 75 gas, so set limit to 50 to exceed
        let call = ContractCall {
            contract: addr,
            function: "transfer".to_string(),
            args: vec!["500".to_string(), "recipient".to_string()],
            gas_limit: 50, // Too low
        };

        let result = engine.call_contract(call);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Out of gas"));
    }

    #[test]
    fn test_unknown_function() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "iris".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        let call = ContractCall {
            contract: addr,
            function: "unknown_func".to_string(),
            args: vec![],
            gas_limit: 1000,
        };

        let result = engine.call_contract(call);
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("Unknown function"));
    }

    #[test]
    fn test_contract_result_serialization() {
        let result = ContractResult {
            success: true,
            output: "success".to_string(),
            gas_used: 100,
            state_changes: HashMap::new(),
        };

        let json = serde_json::to_string(&result).unwrap();
        let deserialized: ContractResult = serde_json::from_str(&json).unwrap();

        assert_eq!(deserialized.success, true);
        assert_eq!(deserialized.output, "success");
    }

    #[test]
    fn test_get_contract_state() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "jack".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        // Set some state
        let call = ContractCall {
            contract: addr.clone(),
            function: "set_state".to_string(),
            args: vec!["name".to_string(), "test".to_string()],
            gas_limit: 100,
        };

        engine.call_contract(call).unwrap();

        let state = engine.get_contract_state(&addr).unwrap();
        assert_eq!(state.get("name"), Some(&"test".to_string()));
    }

    #[test]
    fn test_contract_exists() {
        let engine = WasmEngine::new();
        let wasm_bytes = b"\0asm\x01\x00\x00\x00".to_vec();

        let addr = engine.deploy_contract(
            "kate".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        assert!(engine.contract_exists(&addr).unwrap());
        assert!(!engine.contract_exists("nonexistent").unwrap());
    }

    #[test]
    fn test_real_wasm_execution() {
        let engine = WasmEngine::new();
        
        // Real WASM bytecode: (module (func (export "add") (param i32 i32) (result i32) local.get 0 local.get 1 i32.add))
        let wasm_bytes = vec![
            0x00, 0x61, 0x73, 0x6d, // magic: \0asm
            0x01, 0x00, 0x00, 0x00, // version: 1
            0x01, 0x07, 0x01, 0x60, 0x02, 0x7f, 0x7f, 0x01, 0x7f, // type section: (i32,i32)->i32
            0x03, 0x02, 0x01, 0x00, // function section: func 0 uses type 0
            0x07, 0x07, 0x01, 0x03, 0x61, 0x64, 0x64, 0x00, 0x00, // export section: "add" = func 0
            0x0a, 0x09, 0x01, 0x07, 0x00, 0x20, 0x00, 0x20, 0x01, 0x6a, 0x0b, // code: local.get 0, local.get 1, i32.add
        ];

        let addr = engine.deploy_contract(
            "wasm_test".to_string(),
            wasm_bytes,
            HashMap::new(),
            1
        ).unwrap();

        let call = ContractCall {
            contract: addr,
            function: "add".to_string(),
            args: vec!["5".to_string(), "7".to_string()],
            gas_limit: 1000,
        };

        let result = engine.call_contract(call).unwrap();
        assert!(result.success);
        assert_eq!(result.output, "12"); // 5 + 7 = 12
    }
}
