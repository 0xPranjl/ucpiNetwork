// nolint
// autogenerated code using github.com/rigelrozanski/multitool
// aliases generated for the following subdirectories:
// ALIASGEN: github.com/enigmampc/SecretNetwork/x/compute/internal/types
// ALIASGEN: github.com/enigmampc/SecretNetwork/x/compute/internal/keeper
package registration

import (
	"github.com/enigmampc/SecretNetwork/x/registration/internal/keeper"
	"github.com/enigmampc/SecretNetwork/x/registration/internal/keeper/enclave"
	"github.com/enigmampc/SecretNetwork/x/registration/internal/types"
)

const (
	ModuleName             = types.ModuleName
	StoreKey               = types.StoreKey
	TStoreKey              = types.TStoreKey
	QuerierRoute           = types.QuerierRoute
	RouterKey              = types.RouterKey
	EnclaveRegistrationKey = types.EnclaveRegistrationKey
	QueryEncryptedSeed     = keeper.QueryEncryptedSeed
	QueryMasterCertificate = keeper.QueryMasterCertificate
	SecretNodeSeedConfig   = types.SecretNodeSeedConfig
	SecretNodeCfgFolder    = types.SecretNodeCfgFolder
	EncryptedKeyLength     = types.EncryptedKeyLength
	AttestationCertPath    = types.AttestationCertPath
	IoExchMasterCertPath   = types.IoExchMasterCertPath
	NodeExchMasterCertPath = types.NodeExchMasterCertPath
)

var (
	// functions aliases
	RegisterCodec               = types.RegisterLegacyAminoCodec
	RegisterInterfaces          = types.RegisterInterfaces
	ValidateGenesis             = types.ValidateGenesis
	InitGenesis                 = keeper.InitGenesis
	ExportGenesis               = keeper.ExportGenesis
	NewKeeper                   = keeper.NewKeeper
	NewQuerier                  = keeper.NewQuerier
	NewLegacyQuerier            = keeper.NewLegacyQuerier
	GetGenesisStateFromAppState = keeper.GetGenesisStateFromAppState
	IsHexString                 = keeper.IsHexString

	// variable aliases
	ModuleCdc               = types.ModuleCdc
	DefaultCodespace        = types.DefaultCodespace
	ErrAuthenticateFailed   = types.ErrAuthenticateFailed
	ErrSeedInitFailed       = types.ErrSeedInitFailed
	RegistrationStorePrefix = types.RegistrationStorePrefix
	ErrInvalidType          = types.ErrInvalidType
)

type (
	MsgRaAuthenticate = types.RaAuthenticate
	GenesisState      = types.GenesisState
	Keeper            = keeper.Keeper
	SeedConfig        = types.SeedConfig
	EnclaveApi        = enclave.API
	MasterCertificate = types.MasterCertificate
	Key               = types.Key
)
