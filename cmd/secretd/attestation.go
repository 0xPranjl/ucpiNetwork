//go:build !ucpicli
// +build !ucpicli

package main

import (
	"bytes"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"

	"github.com/cosmos/cosmos-sdk/client"
	"github.com/cosmos/cosmos-sdk/client/flags"
	"github.com/cosmos/cosmos-sdk/codec"
	"github.com/cosmos/cosmos-sdk/server"
	"github.com/cosmos/cosmos-sdk/x/genutil"
	genutiltypes "github.com/cosmos/cosmos-sdk/x/genutil/types"
	"github.com/enigmampc/ucpiNetwork/go-cosmwasm/api"
	reg "github.com/enigmampc/ucpiNetwork/x/registration"
	ra "github.com/enigmampc/ucpiNetwork/x/registration/remote_attestation"
	"github.com/spf13/cobra"
)

const (
	flagReset                     = "reset"
	flagPulsar                    = "pulsar"
	flagCustomRegistrationService = "registration-service"
)

const (
	flagLegacyRegistrationNode = "registration-node"
	flagLegacyBootstrapNode    = "node"
)

const (
	mainnetRegistrationService = "https://mainnet-register.ucpilabs.com/api/registernode"
	pulsarRegistrationService  = "https://testnet-register.ucpilabs.com/api/registernode"
)

func InitAttestation() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init-enclave [output-file]",
		Short: "Perform remote attestation of the enclave",
		Long: `Create attestation report, signed by Intel which is used in the registation process of
the node to the chain. This process, if successful, will output a certificate which is used to authenticate with the 
blockchain. Writes the certificate in DER format to ~/attestation_cert
`,
		Args: cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			sgxucpisDir := os.Getenv("ucpi_SGX_STORAGE")
			if sgxucpisDir == "" {
				sgxucpisDir = os.ExpandEnv("/opt/ucpi/.sgx_ucpis")
			}

			// create sgx ucpis dir if it doesn't exist
			if _, err := os.Stat(sgxucpisDir); !os.IsNotExist(err) {
				err := os.MkdirAll(sgxucpisDir, 0o777)
				if err != nil {
					return err
				}
			}

			sgxucpisPath := sgxucpisDir + string(os.PathSeparator) + reg.EnclaveRegistrationKey

			resetFlag, err := cmd.Flags().GetBool(flagReset)
			if err != nil {
				return fmt.Errorf("error with reset flag: %s", err)
			}

			if !resetFlag {
				if _, err := os.Stat(sgxucpisPath); os.IsNotExist(err) {
					fmt.Println("Creating new enclave registration key")
					_, err := api.KeyGen()
					if err != nil {
						return fmt.Errorf("failed to initialize enclave: %w", err)
					}
				} else {
					fmt.Println("Enclave key already exists. If you wish to overwrite and reset the node, use the --reset flag")
				}
			} else {
				fmt.Println("Reset enclave flag set, generating new enclave registration key. You must now re-register the node")
				_, err := api.KeyGen()
				if err != nil {
					return fmt.Errorf("failed to initialize enclave: %w", err)
				}
			}

			spidFile, err := Asset("spid.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			apiKeyFile, err := Asset("api_key.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			_, err = api.CreateAttestationReport(spidFile, apiKeyFile)
			if err != nil {
				return fmt.Errorf("failed to create attestation report: %w", err)
			}
			return nil
		},
	}
	cmd.Flags().Bool(flagReset, false, "Optional flag to regenerate the enclave registration key")

	return cmd
}

func InitBootstrapCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "init-bootstrap [node-exchange-file] [io-exchange-file]",
		Short: "Perform bootstrap initialization",
		Long: `Create attestation report, signed by Intel which is used in the registration process of
the node to the chain. This process, if successful, will output a certificate which is used to authenticate with the 
blockchain. Writes the certificate in DER format to ~/attestation_cert
`,
		Args: cobra.MaximumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			clientCtx := client.GetClientContextFromCmd(cmd)
			depCdc := clientCtx.Codec
			cdc := depCdc.(codec.Codec)

			serverCtx := server.GetServerContextFromCmd(cmd)
			config := serverCtx.Config

			genFile := config.GenesisFile()
			appState, genDoc, err := genutiltypes.GenesisStateFromGenFile(genFile)
			if err != nil {
				return fmt.Errorf("failed to unmarshal genesis state: %w", err)
			}

			regGenState := reg.GetGenesisStateFromAppState(cdc, appState)

			spidFile, err := Asset("spid.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			apiKeyFile, err := Asset("api_key.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			// the master key of the generated certificate is returned here
			masterKey, err := api.InitBootstrap(spidFile, apiKeyFile)
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			userHome, _ := os.UserHomeDir()

			// Load consensus_seed_exchange_pubkey
			cert := []byte(nil)
			if len(args) >= 1 {
				cert, err = ioutil.ReadFile(args[0])
				if err != nil {
					return err
				}
			} else {
				cert, err = ioutil.ReadFile(filepath.Join(userHome, reg.NodeExchMasterCertPath))
				if err != nil {
					return err
				}
			}

			pubkey, err := ra.VerifyRaCert(cert)
			if err != nil {
				return err
			}

			fmt.Println(fmt.Sprintf("%s", hex.EncodeToString(pubkey)))
			fmt.Println(fmt.Sprintf("%s", hex.EncodeToString(masterKey)))

			// sanity check - make sure the certificate we're using matches the generated key
			if hex.EncodeToString(pubkey) != hex.EncodeToString(masterKey) {
				return fmt.Errorf("invalid certificate for master public key")
			}

			regGenState.NodeExchMasterCertificate.Bytes = cert

			// Load consensus_io_exchange_pubkey
			if len(args) == 2 {
				cert, err = ioutil.ReadFile(args[1])
				if err != nil {
					return err
				}
			} else {
				cert, err = ioutil.ReadFile(filepath.Join(userHome, reg.IoExchMasterCertPath))
				if err != nil {
					return err
				}
			}
			regGenState.IoMasterCertificate.Bytes = cert

			// Create genesis state from certificates
			regGenStateBz, err := cdc.MarshalJSON(&regGenState)
			if err != nil {
				return fmt.Errorf("failed to marshal auth genesis state: %w", err)
			}

			appState[reg.ModuleName] = regGenStateBz

			appStateJSON, err := json.Marshal(appState)
			if err != nil {
				return fmt.Errorf("failed to marshal application genesis state: %w", err)
			}

			genDoc.AppState = appStateJSON
			return genutil.ExportGenesisFile(genDoc, genFile)
		},
	}

	return cmd
}

func ParseCert() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "parse [cert file]",
		Short: "Verify and parse a certificate file",
		Long: "Helper to verify generated credentials, and extract the public key of the ucpi node, which is used to" +
			"register the node, during node initialization",
		Args: cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			// parse coins trying to be sent
			cert, err := ioutil.ReadFile(args[0])
			if err != nil {
				return err
			}

			pubkey, err := ra.VerifyRaCert(cert)
			if err != nil {
				return err
			}

			fmt.Println(fmt.Sprintf("0x%s", hex.EncodeToString(pubkey)))
			return nil
		},
	}

	return cmd
}

func Configureucpi() *cobra.Command {
	cmd := &cobra.Command{
		Use: "configure-ucpi [master-cert] [seed]",
		Short: "After registration is successful, configure the ucpi node with the credentials file and the encrypted " +
			"seed that was written on-chain",
		Args: cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			cert, err := ioutil.ReadFile(args[0])
			if err != nil {
				return err
			}

			// We expect seed to be 48 bytes of encrypted data (aka 96 hex chars) [32 bytes + 12 IV]
			seed := args[1]
			if len(seed) != reg.EncryptedKeyLength || !reg.IsHexString(seed) {
				return fmt.Errorf("invalid encrypted seed format (requires hex string of length 96 without 0x prefix)")
			}

			cfg := reg.SeedConfig{
				EncryptedKey: seed,
				MasterCert:   base64.StdEncoding.EncodeToString(cert),
			}

			cfgBytes, err := json.Marshal(&cfg)
			if err != nil {
				return err
			}

			homeDir, err := cmd.Flags().GetString(flags.FlagHome)
			if err != nil {
				return err
			}

			// Create .ucpid/.node directory if it doesn't exist
			nodeDir := filepath.Join(homeDir, reg.ucpiNodeCfgFolder)
			err = os.MkdirAll(nodeDir, os.ModePerm)
			if err != nil {
				return err
			}

			seedFilePath := filepath.Join(nodeDir, reg.ucpiNodeSeedConfig)

			err = ioutil.WriteFile(seedFilePath, cfgBytes, 0o664)
			if err != nil {
				return err
			}

			return nil
		},
	}

	return cmd
}

func HealthCheck() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "check-enclave",
		Short: "Test enclave status",
		Long:  "Help diagnose issues by performing a basic sanity test that SGX is working properly",
		Args:  cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			res, err := api.HealthCheck()
			if err != nil {
				return fmt.Errorf("failed to start enclave. Enclave returned: %s", err)
			}

			fmt.Println(fmt.Sprintf("SGX enclave health status: %s", res))
			return nil
		},
	}

	return cmd
}

func ResetEnclave() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "reset-enclave",
		Short: "Reset registration & enclave parameters",
		Long: "This will delete all registration and enclave parameters. Use when something goes wrong and you want to start fresh." +
			"You will have to go through registration again to be able to start the node",
		Args: cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			homeDir, err := cmd.Flags().GetString(flags.FlagHome)
			if err != nil {
				return err
			}

			// Remove .ucpid/.node/seed.json
			path := filepath.Join(homeDir, reg.ucpiNodeCfgFolder, reg.ucpiNodeSeedConfig)
			if _, err := os.Stat(path); !os.IsNotExist(err) {
				fmt.Printf("Removing %s\n", path)
				err = os.Remove(path)
				if err != nil {
					return err
				}
			} else {
				if err != nil {
					println(err.Error())
				}
			}

			// remove sgx_ucpis
			sgxucpisDir := os.Getenv("ucpi_SGX_STORAGE")
			if sgxucpisDir == "" {
				sgxucpisDir = os.ExpandEnv("/opt/ucpi/.sgx_ucpis")
			}
			if _, err := os.Stat(sgxucpisDir); !os.IsNotExist(err) {
				fmt.Printf("Removing %s\n", sgxucpisDir)
				err = os.RemoveAll(sgxucpisDir)
				if err != nil {
					return err
				}
				err := os.MkdirAll(sgxucpisDir, 0o777)
				if err != nil {
					return err
				}
			} else {
				if err != nil {
					println(err.Error())
				}
			}
			return nil
		},
	}

	return cmd
}

type OkayResponse struct {
	Status          string `json:"status"`
	Details         KeyVal `json:"details"`
	RegistrationKey string `json:"registration_key"`
}

type KeyVal struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

type ErrorResponse struct {
	Status  string `json:"status"`
	Details string `json:"details"`
}

// AutoRegisterNode *** EXPERIMENTAL ***
func AutoRegisterNode() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "auto-register",
		Short: "Perform remote attestation of the enclave",
		Long: `Automatically handles all registration processes. ***EXPERIMENTAL***
Please report any issues with this command
`,
		Args: cobra.ExactArgs(0),
		RunE: func(cmd *cobra.Command, args []string) error {
			sgxucpisFolder := os.Getenv("ucpi_SGX_STORAGE")
			if sgxucpisFolder == "" {
				sgxucpisFolder = os.ExpandEnv("/opt/ucpi/.sgx_ucpis")
			}

			sgxEnclaveKeyPath := filepath.Join(sgxucpisFolder, reg.EnclaveRegistrationKey)
			sgxAttestationCert := filepath.Join(sgxucpisFolder, reg.AttestationCertPath)

			resetFlag, err := cmd.Flags().GetBool(flagReset)
			if err != nil {
				return fmt.Errorf("error with reset flag: %s", err)
			}

			if !resetFlag {
				if _, err := os.Stat(sgxEnclaveKeyPath); os.IsNotExist(err) {
					fmt.Println("Creating new enclave registration key")
					_, err := api.KeyGen()
					if err != nil {
						return fmt.Errorf("failed to initialize enclave: %w", err)
					}
				} else {
					fmt.Println("Enclave key already exists. If you wish to overwrite and reset the node, use the --reset flag")
					return nil
				}
			} else {
				fmt.Println("Reset enclave flag set, generating new enclave registration key. You must now re-register the node")
				_, err := api.KeyGen()
				if err != nil {
					return fmt.Errorf("failed to initialize enclave: %w", err)
				}
			}

			spidFile, err := Asset("spid.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			apiKeyFile, err := Asset("api_key.txt")
			if err != nil {
				return fmt.Errorf("failed to initialize enclave: %w", err)
			}

			_, err = api.CreateAttestationReport(spidFile, apiKeyFile)
			if err != nil {
				return fmt.Errorf("failed to create attestation report: %w", err)
			}

			// read the attestation certificate that we just created
			cert, err := ioutil.ReadFile(sgxAttestationCert)
			if err != nil {
				_ = os.Remove(sgxAttestationCert)
				return err
			}

			_ = os.Remove(sgxAttestationCert)

			// verify certificate
			_, err = ra.VerifyRaCert(cert)
			if err != nil {
				return err
			}

			regUrl := mainnetRegistrationService

			pulsarFlag, err := cmd.Flags().GetBool(flagPulsar)
			if err != nil {
				return fmt.Errorf("error with testnet flag: %s", err)
			}

			// register the node
			customRegUrl, err := cmd.Flags().GetString(flagCustomRegistrationService)
			if err != nil {
				return err
			}

			if pulsarFlag {
				regUrl = pulsarRegistrationService
				log.Println("Registering node on Pulsar testnet")
			} else if customRegUrl != "" {
				regUrl = customRegUrl
				log.Println("Registering node with custom registration service")
			} else {
				log.Println("Registering node on mainnet")
			}

			// call registration service to register us
			data := []byte(fmt.Sprintf(`{
				"certificate": "%s"
			}`, base64.StdEncoding.EncodeToString(cert)))

			resp, err := http.Post(fmt.Sprintf(`%s`, regUrl), "application/json", bytes.NewBuffer(data))
			defer resp.Body.Close()

			body, err := ioutil.ReadAll(resp.Body)
			if err != nil {
				log.Fatalln(err)
			}

			if resp.StatusCode != http.StatusOK {
				errDetails := ErrorResponse{}
				err := json.Unmarshal(body, &errDetails)
				if err != nil {
					return fmt.Errorf(fmt.Sprintf("Registration TX was not successful - %s", err))
				}
				return fmt.Errorf(fmt.Sprintf("Registration TX was not successful - %s", errDetails.Details))
			}

			details := OkayResponse{}
			err = json.Unmarshal(body, &details)
			if err != nil {
				return fmt.Errorf(fmt.Sprintf("Error getting seed from registration service - %s", err))
			}

			seed := details.Details.Value
			log.Printf(fmt.Sprintf(`seed: %s`, seed))

			if len(seed) > 2 {
				seed = seed[2:]
			}

			if len(seed) != reg.EncryptedKeyLength || !reg.IsHexString(seed) {
				return fmt.Errorf("invalid encrypted seed format (requires hex string of length 96 without 0x prefix)")
			}

			regPublicKey := details.RegistrationKey

			// We expect seed to be 48 bytes of encrypted data (aka 96 hex chars) [32 bytes + 12 IV]

			cfg := reg.SeedConfig{
				EncryptedKey: seed,
				MasterCert:   regPublicKey,
			}

			cfgBytes, err := json.Marshal(&cfg)
			if err != nil {
				return err
			}

			homeDir, err := cmd.Flags().GetString(flags.FlagHome)
			if err != nil {
				return err
			}

			seedCfgFile := filepath.Join(homeDir, reg.ucpiNodeCfgFolder, reg.ucpiNodeSeedConfig)
			seedCfgDir := filepath.Join(homeDir, reg.ucpiNodeCfgFolder)

			// create seed directory if it doesn't exist
			_, err = os.Stat(seedCfgDir)
			if os.IsNotExist(err) {
				err = os.MkdirAll(seedCfgDir, 0o777)
				if err != nil {
					return fmt.Errorf("failed to create directory '%s': %w", seedCfgDir, err)
				}
			}

			// write seed to file - if file doesn't exist, write it. If it does, delete the existing one and create this
			_, err = os.Stat(seedCfgFile)
			if os.IsNotExist(err) {
				err = ioutil.WriteFile(seedCfgFile, cfgBytes, 0o644)
				if err != nil {
					return err
				}
			} else {
				err = os.Remove(seedCfgFile)
				if err != nil {
					return fmt.Errorf("failed to modify file '%s': %w", seedCfgFile, err)
				}

				err = ioutil.WriteFile(seedCfgFile, cfgBytes, 0o644)
				if err != nil {
					return fmt.Errorf("failed to create file '%s': %w", seedCfgFile, err)
				}
			}

			fmt.Println("Done registering! Ready to start...")
			return nil
		},
	}
	cmd.Flags().Bool(flagReset, false, "Optional flag to regenerate the enclave registration key")
	cmd.Flags().Bool(flagPulsar, false, "Set --pulsar flag if registering with the Pulsar testnet")
	cmd.Flags().String(flagCustomRegistrationService, "", "Use this flag if you wish to specify a custom registration service")

	cmd.Flags().String(flagLegacyBootstrapNode, "", "DEPRECATED: This flag is no longer required or in use")
	cmd.Flags().String(flagLegacyRegistrationNode, "", "DEPRECATED: This flag is no longer required or in use")

	return cmd
}
