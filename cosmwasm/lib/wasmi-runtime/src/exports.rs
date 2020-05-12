use enclave_ffi_types::{Ctx, EnclaveBuffer, HandleResult, InitResult, QueryResult};
use std::ffi::c_void;

use crate::crypto;
use crate::crypto::{PubKey, AESKey, SEED_KEY_SIZE, UNCOMPRESSED_PUBLIC_KEY_SIZE, KeyPair, PUBLIC_KEY_SIZE};
use crate::results::{
    result_handle_success_to_handleresult, result_init_success_to_initresult,
    result_query_success_to_queryresult,
};
use log::*;
use sgx_trts::trts::{
    rsgx_lfence, rsgx_raw_is_outside_enclave, rsgx_sfence, rsgx_slice_is_outside_enclave,
};
use sgx_types::{sgx_quote_sign_type_t, sgx_report_t, sgx_status_t, sgx_target_info_t};
use std::ptr::null;
use std::slice;


use crate::consts::{NODE_SK_SEALING_PATH, SEED_SEALING_PATH};
pub use crate::crypto::traits::{SealedKey, Encryptable, Kdf};


#[cfg(feature = "SGX_MODE_HW")]
use crate::attestation::create_attestation_report;
#[cfg(feature = "SGX_MODE_HW")]
use crate::attestation::create_attestation_certificate;

#[cfg(not(feature = "SGX_MODE_HW"))]
use crate::attestation::{create_report_with_data, software_mode_quote};
use crate::cert::verify_mra_cert;

use crate::storage::{write_to_untrusted};

#[no_mangle]
pub extern "C" fn ecall_allocate(buffer: *const u8, length: usize) -> EnclaveBuffer {
    let slice = unsafe { std::slice::from_raw_parts(buffer, length) };
    let vector_copy = slice.to_vec();
    let boxed_vector = Box::new(vector_copy);
    let heap_pointer = Box::into_raw(boxed_vector);
    EnclaveBuffer {
        ptr: heap_pointer as *mut c_void,
    }
}

/// Take a pointer as returned by `ecall_allocate` and recover the Vec<u8> inside of it.
pub unsafe fn recover_buffer(ptr: EnclaveBuffer) -> Option<Vec<u8>> {
    if ptr.ptr.is_null() {
        return None;
    }
    let boxed_vector = Box::from_raw(ptr.ptr as *mut Vec<u8>);
    Some(*boxed_vector)
}

#[no_mangle]
pub extern "C" fn ecall_init(
    context: Ctx,
    gas_limit: u64,
    contract: *const u8,
    contract_len: usize,
    env: *const u8,
    env_len: usize,
    msg: *const u8,
    msg_len: usize,
) -> InitResult {
    let contract = unsafe { std::slice::from_raw_parts(contract, contract_len) };
    let env = unsafe { std::slice::from_raw_parts(env, env_len) };
    let msg = unsafe { std::slice::from_raw_parts(msg, msg_len) };

    let result = super::contract_operations::init(context, gas_limit, contract, env, msg);
    result_init_success_to_initresult(result)
}

#[no_mangle]
pub extern "C" fn ecall_handle(
    context: Ctx,
    gas_limit: u64,
    contract: *const u8,
    contract_len: usize,
    env: *const u8,
    env_len: usize,
    msg: *const u8,
    msg_len: usize,
) -> HandleResult {
    let contract = unsafe { std::slice::from_raw_parts(contract, contract_len) };
    let env = unsafe { std::slice::from_raw_parts(env, env_len) };
    let msg = unsafe { std::slice::from_raw_parts(msg, msg_len) };

    let result = super::contract_operations::handle(context, gas_limit, contract, env, msg);
    result_handle_success_to_handleresult(result)
}

#[no_mangle]
pub extern "C" fn ecall_query(
    context: Ctx,
    gas_limit: u64,
    contract: *const u8,
    contract_len: usize,
    msg: *const u8,
    msg_len: usize,
) -> QueryResult {
    let contract = unsafe { std::slice::from_raw_parts(contract, contract_len) };
    let msg = unsafe { std::slice::from_raw_parts(msg, msg_len) };

    let result = super::contract_operations::query(context, gas_limit, contract, msg);
    result_query_success_to_queryresult(result)
}

// gen (sk_node,pk_node) keypair for new node registration
#[no_mangle]
pub unsafe extern "C" fn ecall_key_gen(pk_node: *mut PubKey) -> sgx_types::sgx_status_t {
    // Generate node-specific key-pair
    let key_pair = match crypto::KeyPair::new() {
        Ok(kp) => kp,
        Err(err) => return sgx_status_t::SGX_ERROR_UNEXPECTED,
    };

    // let privkey = key_pair.get_privkey();
    match key_pair.seal(NODE_SK_SEALING_PATH) {
        Err(err) => return sgx_status_t::SGX_ERROR_UNEXPECTED,
        Ok(_) => { /* continue */ }
    }; // can read with SecretKey::from_slice()

    let pubkey = key_pair.get_pubkey();

    (&mut *pk_node).clone_from_slice(&pubkey);
    sgx_status_t::SGX_SUCCESS
}

#[cfg(feature = "SGX_MODE_HW")]
#[no_mangle]
pub extern "C" fn ecall_get_attestation_report() -> sgx_status_t {
    let (private_key_der, cert) =
        match create_attestation_certificate(sgx_quote_sign_type_t::SGX_UNLINKABLE_SIGNATURE) {
            Err(e) => {
                error!("Error in create_attestation_certificate: {:?}", e);
                return e;
            }
            Ok(res) => res,
        };
    // info!("private key {:?}, cert: {:?}", private_key_der, cert);

    if let Err(status) = write_to_untrusted(cert.as_slice(), "attestation_cert.der") {
        return status;
    }
    //seal(private_key_der, "ecc_cert_private.der")
    sgx_status_t::SGX_SUCCESS
}

#[cfg(not(feature = "SGX_MODE_HW"))]
#[no_mangle]
pub extern "C" fn ecall_get_attestation_report() -> sgx_status_t {
    software_mode_quote()
}

#[cfg(not(feature = "SGX_MODE_HW"))]
#[no_mangle]
// todo: replace 32 with crypto consts once I have crypto library
pub extern "C" fn ecall_get_encrypted_seed(
    cert: *const u8,
    cert_len: u32,
    seed: &mut [u8; 32],
) -> sgx_status_t {
    // just return the seed
    sgx_status_t::SGX_SUCCESS
}

#[no_mangle]
pub extern "C" fn ecall_init_bootstrap(
    public_key: &mut [u8; PUBLIC_KEY_SIZE]) -> sgx_status_t {

    if rsgx_slice_is_outside_enclave(public_key) {
        error!("Tried to access memory outside enclave -- rsgx_slice_is_outside_enclave");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    rsgx_sfence();


    // Generate node-specific key-pair
    let seed = match crypto::KeyPair::new() {
        Ok(seed) => seed,
        Err(err) => return sgx_status_t::SGX_ERROR_UNEXPECTED,
    };

    info!("DEBUG: key: {:?}", seed.get_privkey());

    // let seed = key_pair.get_privkey();
    match seed.seal(SEED_SEALING_PATH) {
        Err(err) => return sgx_status_t::SGX_ERROR_UNEXPECTED,
        Ok(_) => { /* continue */ }
    };

    // don't want to copy the first byte (no need to pass the 0x4 uncompressed byte)
    public_key.copy_from_slice(&seed.get_pubkey()[1..UNCOMPRESSED_PUBLIC_KEY_SIZE]);

    // info!("DEBUG: public key: {:?}", seed);

    sgx_status_t::SGX_SUCCESS
}

/**
  *  `ecall_get_encrypted_seed`
  *
  *  This call is used to help new nodes register in the network. The function will authenticate the
  *  new node, based on a received certificate. If the node is authenticated successfully, the seed
  *  will be encrypted and shared with the registering node.
  *
  *  The seed is encrypted with a key derived from the secret master key of the chain, and the public
  *  key of the requesting chain
  *
  */
#[cfg(feature = "SGX_MODE_HW")]
#[no_mangle]
// todo: replace 32 with crypto consts once I have crypto library
pub extern "C" fn ecall_get_encrypted_seed(
    cert: *const u8,
    cert_len: u32,
    seed: &mut [u8; 32]
) -> sgx_status_t {
    if rsgx_slice_is_outside_enclave(seed) {
        error!("Tried to access memory outside enclave -- rsgx_slice_is_outside_enclave");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    rsgx_sfence();

    if cert.is_null() || cert_len == 0 {
        error!("Tried to access an empty pointer - cert.is_null()");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    rsgx_lfence();

    let cert_slice = unsafe { std::slice::from_raw_parts(cert, cert_len as usize) };

    let pk = match verify_mra_cert(cert_slice) {
        Err(e) => {
            error!("Error in validating certificate: {:?}", e);
            return e;
        }
        Ok(res) => res,
    };

    if pk.len() != crypto::PUBLIC_KEY_SIZE {
        error!("Got public key from certificate with the wrong size: {:?}", pk.len());
        return sgx_status_t::SGX_ERROR_UNEXPECTED
    }

    let mut target_public_key: [u8; 65] = [4u8; 65];

    let node_secret = match crypto::KeyPair::unseal(NODE_SK_SEALING_PATH) {
        Ok(r) => r,
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    let node_seed = match crypto::AESKey::unseal(SEED_SEALING_PATH) {
        Ok(r) => r,
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    target_public_key.copy_from_slice(&pk);

    let shared_enc_key = match node_secret.derive_key(&target_public_key) {
        Ok(r) => r,
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    let res = match AESKey::new_from_slice(&shared_enc_key).encrypt(&node_seed.get().to_vec()) {
        Ok(r) => {
            if r.len() != SEED_KEY_SIZE {
                error!("wtf?");
                return sgx_status_t::SGX_ERROR_UNEXPECTED
            }
            r
        },
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    seed.copy_from_slice(&res);

    sgx_status_t::SGX_SUCCESS
}

/**
  *  `ecall_init_seed`
  *
  *  This function is called during initialization of __non__ bootstrap nodes.
  *
  *  It receives the master public key (pk_io) and uses it, and its node key (generated in [ecall_key_gen])
  *  to decrypt the seed.
  *
  *  The seed was encrypted using Diffie-Hellman in the function [ecall_get_encrypted_seed]
  *
  */
#[no_mangle]
pub unsafe extern "C" fn ecall_init_seed(
    public_key: *const u8,
    public_key_len: u32,
    encrypted_seed: *const u8,
    encrypted_seed_len: u32,
) -> sgx_status_t {
    if public_key.is_null() || public_key_len == 0 {
        error!("Tried to access an empty pointer - public_key.is_null()");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    rsgx_lfence();

    if encrypted_seed.is_null() || encrypted_seed_len == 0 {
        error!("Tried to access an empty pointer - encrypted_seed.is_null()");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    rsgx_lfence();

    let public_key_slice = slice::from_raw_parts(public_key, public_key_len as usize);
    let encrypted_seed_slice = slice::from_raw_parts(encrypted_seed, encrypted_seed_len as usize);

    let mut target_public_key: [u8; UNCOMPRESSED_PUBLIC_KEY_SIZE] = [4u8; UNCOMPRESSED_PUBLIC_KEY_SIZE];
    if public_key_slice.len() != UNCOMPRESSED_PUBLIC_KEY_SIZE {
        error!("Got public key of a weird size");
        return sgx_status_t::SGX_ERROR_UNEXPECTED;
    }
    target_public_key.copy_from_slice(&public_key_slice);

    let node_secret = match crypto::KeyPair::unseal(NODE_SK_SEALING_PATH) {
        Ok(r) => r,
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    let shared_enc_key = match node_secret.derive_key(&target_public_key) {
        Ok(r) => r,
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    let res = match AESKey::new_from_slice(&shared_enc_key).decrypt(&encrypted_seed_slice) {
        Ok(r) => {
            if r.len() != SEED_KEY_SIZE {
                error!("wtf2?");
                return sgx_status_t::SGX_ERROR_UNEXPECTED
            }
            r
        },
        Err(e) => {
            return sgx_status_t::SGX_ERROR_UNEXPECTED
        }
    };

    let mut seed_buf: [u8; 32] = [0u8; 32];
    seed_buf.copy_from_slice(&res);

    info!("Decrypted seed: {:?}", seed_buf);

    AESKey::new_from_slice(&seed_buf).seal(SEED_SEALING_PATH);

    sgx_status_t::SGX_SUCCESS

}
