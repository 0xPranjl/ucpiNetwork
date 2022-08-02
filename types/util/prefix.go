package util

import "fmt"

const (
	// Bech32PrefixAccAddr defines the Bech32 prefix of an account's address
	Bech32PrefixAccAddr = "ucpi"
	// Bech32PrefixAccPub defines the Bech32 prefix of an account's public key
	Bech32PrefixAccPub = "ucpipub"
	// Bech32PrefixValAddr defines the Bech32 prefix of a validator's operator address
	Bech32PrefixValAddr = "ucpivaloper"
	// Bech32PrefixValPub defines the Bech32 prefix of a validator's operator public key
	Bech32PrefixValPub = "ucpivaloperpub"
	// Bech32PrefixConsAddr defines the Bech32 prefix of a consensus node address
	Bech32PrefixConsAddr = "ucpivalcons"
	// Bech32PrefixConsPub defines the Bech32 prefix of a consensus node public key
	Bech32PrefixConsPub = "ucpivalconspub"
	CoinType            = 529
	CoinPurpose         = 44
)

// AddressVerifier ucpi address verifier
var AddressVerifier = func(bz []byte) error {
	if n := len(bz); n != 20 {
		return fmt.Errorf("incorrect address length %d", n)
	}

	return nil
}
