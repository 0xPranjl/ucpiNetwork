package types

import (
	sdk "github.com/cosmos/cosmos-sdk/types"
)

const (
	// ModuleName is the name of the contract module
	ModuleName = "compute"

	// StoreKey is the string store representation
	StoreKey = ModuleName

	// TStoreKey is the string transient store representation
	TStoreKey = "transient_" + ModuleName

	// QuerierRoute is the querier route for the staking module
	QuerierRoute = ModuleName

	// RouterKey is the msg router key for the staking module
	RouterKey = ModuleName
)

// nolint
var (
	CodeKeyPrefix           = []byte{0x01}
	ContractKeyPrefix       = []byte{0x02}
	ContractStorePrefix     = []byte{0x03}
	SequenceKeyPrefix       = []byte{0x04}
	ContractEnclaveIdPrefix = []byte{0x06}
	ContractLabelPrefix     = []byte{0x07}
	KeyLastCodeID           = append(SequenceKeyPrefix, []byte("lastCodeId")...)
	KeyLastInstanceID       = append(SequenceKeyPrefix, []byte("lastContractId")...)
)

// GetCodeKey constructs the key for retreiving the ID for the WASM code
func GetCodeKey(codeID uint64) []byte {
	contractIDBz := sdk.Uint64ToBigEndian(codeID)
	return append(CodeKeyPrefix, contractIDBz...)
}

// GetContractAddressKey returns the key for the WASM contract instance
func GetContractAddressKey(addr sdk.AccAddress) []byte {
	return append(ContractKeyPrefix, addr...)
}

// GetContractAddressKey returns the key for the WASM contract instance
func GetContractEnclaveKey(addr sdk.AccAddress) []byte {
	return append(ContractEnclaveIdPrefix, addr...)
}

// GetContractStorePrefixKey returns the store prefix for the WASM contract instance
func GetContractStorePrefixKey(addr sdk.AccAddress) []byte {
	return append(ContractStorePrefix, addr...)
}

// GetContractStorePrefixKey returns the store prefix for the WASM contract instance
func GetContractLabelPrefix(addr string) []byte {
	return append(ContractLabelPrefix, []byte(addr)...)
}
