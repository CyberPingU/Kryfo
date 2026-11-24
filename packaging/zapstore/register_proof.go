package main

import (
	"bytes"
	"context"
	"crypto"
	"crypto/x509"
	"fmt"
	"os"
	"strings"
	"time"

	gonostr "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip19"
	keystore "github.com/pavlo-v-chernykh/keystore-go/v4"
)

func main() {
	keystorePath := os.Getenv("KEYSTORE_PATH")
	if keystorePath == "" {
		if len(os.Args) > 1 {
			keystorePath = os.Args[1]
		} else {
			keystorePath = "dreadful.keystore"
		}
	}

	keystorePassword := strings.TrimSpace(os.Getenv("KEYSTORE_PASSWORD"))
	if keystorePassword == "" {
		fmt.Fprintf(os.Stderr, "Error: KEYSTORE_PASSWORD environment variable is empty\n")
		os.Exit(1)
	}

	keyAlias := strings.TrimSpace(os.Getenv("KEY_ALIAS"))

	signWith := strings.TrimSpace(os.Getenv("SIGN_WITH"))
	signWith = strings.Trim(signWith, "\"'`\r\n ")
	if signWith == "" {
		fmt.Fprintf(os.Stderr, "Error: SIGN_WITH environment variable is empty\n")
		os.Exit(1)
	}

	relayURL := os.Getenv("RELAY_URL")
	if relayURL == "" {
		relayURL = "wss://relay.zapstore.dev"
	}

	var skHex string
	if strings.HasPrefix(signWith, "nsec1") {
		prefix, val, err := nip19.Decode(signWith)
		if err != nil || prefix != "nsec" {
			fmt.Fprintf(os.Stderr, "Error decoding nsec: %v\n", err)
			os.Exit(1)
		}
		skHex = val.(string)
	} else {
		skHex = signWith
	}

	pubkeyHex, err := gonostr.GetPublicKey(skHex)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error deriving Nostr public key: %v\n", err)
		os.Exit(1)
	}
	npub, _ := nip19.EncodePublicKey(pubkeyHex)
	fmt.Printf("Nostr signer: %s (%s)\n", npub, pubkeyHex)

	keystoreData, err := os.ReadFile(keystorePath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading keystore file %s: %v\n", keystorePath, err)
		os.Exit(1)
	}
	fmt.Printf("Read keystore file %s (%d bytes)\n", keystorePath, len(keystoreData))

	var privateKey crypto.PrivateKey
	var certificate *x509.Certificate

	if IsPKCS12(keystoreData) {
		fmt.Println("Keystore format: PKCS#12")
		privateKey, certificate, err = LoadPKCS12(keystoreData, keystorePassword)
		if err != nil {
			fmt.Fprintf(os.Stderr, "LoadPKCS12 failed: %v\n", err)
		}
	} else if IsJKS(keystoreData) {
		fmt.Println("Keystore format: JKS")
		ks := keystore.New(keystore.WithOrderedAliases())
		if loadErr := ks.Load(bytes.NewReader(keystoreData), []byte(keystorePassword)); loadErr != nil {
			err = fmt.Errorf("JKS password verification failed: %w", loadErr)
		} else {
			aliases := ks.Aliases()
			fmt.Printf("JKS aliases found: %v\n", aliases)
			selectedAlias := keyAlias
			if selectedAlias == "" || !ks.IsPrivateKeyEntry(selectedAlias) {
				for _, a := range aliases {
					if ks.IsPrivateKeyEntry(a) {
						selectedAlias = a
						break
					}
				}
			}
			fmt.Printf("Using JKS alias: %q\n", selectedAlias)
			privateKey, certificate, err = LoadJKS(keystoreData, []byte(keystorePassword), []byte(keystorePassword), selectedAlias)
		}
	} else {
		err = fmt.Errorf("unrecognized keystore format (magic bytes: %x)", keystoreData[:min(8, len(keystoreData))])
	}

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading keystore: %v\n", err)
		os.Exit(1)
	}

	certHash := ComputeCertHash(certificate)
	fmt.Printf("Keystore certificate SHA-256: %s\n", certHash)

	proof, err := GenerateIdentityProof(privateKey, certificate, pubkeyHex, &IdentityProofOptions{
		Expiry: 2 * 365 * 24 * time.Hour,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error generating NIP-C1 identity proof: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Generated NIP-C1 proof until %s\n", proof.ExpiryTime().Format(time.RFC3339))

	event := &gonostr.Event{
		Kind:      30509,
		PubKey:    pubkeyHex,
		CreatedAt: gonostr.Timestamp(proof.CreatedAt),
		Tags:      proof.ToEventTags(),
		Content:   "",
	}

	if err := event.Sign(skHex); err != nil {
		fmt.Fprintf(os.Stderr, "Error signing Nostr proof event: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Signed Nostr event %s (kind %d)\n", event.ID, event.Kind)

	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()

	fmt.Printf("Connecting to relay %s...\n", relayURL)
	relay, err := gonostr.RelayConnect(ctx, relayURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error connecting to relay %s: %v\n", relayURL, err)
		os.Exit(1)
	}
	defer relay.Close()

	fmt.Printf("Publishing event to %s...\n", relayURL)
	if err := relay.Publish(ctx, *event); err != nil {
		fmt.Fprintf(os.Stderr, "Error publishing proof event to relay: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("=== SUCCESS ===")
	fmt.Printf("C1 proof event successfully published to %s!\n", relayURL)
	fmt.Printf("Event ID: %s\n", event.ID)
	fmt.Printf("App certificate %s is now claimed by %s\n", certHash, npub)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
