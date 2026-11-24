package main

import (
	"bytes"
	"context"
	"crypto"
	"crypto/x509"
	"fmt"
	"os"
	"strings"

	gonostr "github.com/nbd-wtf/go-nostr"
	"github.com/nbd-wtf/go-nostr/nip19"
	keystore "github.com/pavlo-v-chernykh/keystore-go/v4"
	"github.com/zapstore/zsp/v2"
)

type keystoreSigner struct {
	key    crypto.PrivateKey
	cert   *x509.Certificate
	pubkey string
}

func (s keystoreSigner) SignProof(_ context.Context, createdAt, expiry int64) (zsp.ProofSignature, error) {
	signature, err := SignProofMessage(s.key, s.pubkey, createdAt, expiry)
	if err != nil {
		return zsp.ProofSignature{}, err
	}
	return zsp.ProofSignature{
		PublicKey:       s.pubkey,
		CertificateHash: ComputeCertHash(s.cert),
		Signature:       signature,
	}, nil
}

func main() {
	keystorePath := os.Getenv("KEYSTORE_PATH")
	if keystorePath == "" {
		if len(os.Args) > 1 {
			keystorePath = os.Args[1]
		} else {
			keystorePath = "dreadful.keystore"
		}
	}

	configPath := os.Getenv("CONFIG_PATH")
	if configPath == "" {
		configPath = "zapstore.yaml"
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
	os.Setenv("SIGN_WITH", signWith)

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

	fmt.Printf("Loading Zapstore config: %s\n", configPath)
	cfg, err := zsp.LoadConfig(configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error loading config %s: %v\n", configPath, err)
		os.Exit(1)
	}

	ctx := context.Background()

	fmt.Println("Fetching release candidates according to zapstore.yaml...")
	candidates, err := zsp.Fetch(ctx, cfg.Fetch, zsp.FetchOptions{
		OnProgress: func(p zsp.Progress) {
			if p.Phase != "" {
				fmt.Printf("[%s] %s\n", p.Phase, p.Target)
			}
		},
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error fetching release candidates: %v\n", err)
		os.Exit(1)
	}
	if len(candidates) == 0 {
		fmt.Fprintf(os.Stderr, "Error: no matching APK candidate found\n")
		os.Exit(1)
	}
	candidate := candidates[0]
	defer candidate.Close()

	fmt.Printf("Selected APK candidate: %s v%s (code %d, SHA-256: %s)\n",
		candidate.AppID, candidate.VersionName, candidate.VersionCode, candidate.Hash)

	proofSigner := keystoreSigner{
		key:    privateKey,
		cert:   certificate,
		pubkey: pubkeyHex,
	}

	fmt.Println("Publishing application release and NIP-C1 proof together to Zapstore...")
	result, err := zsp.Publish(ctx, cfg.Publish, candidate, zsp.PublishOptions{
		ProofSigner:       proofSigner,
		OverwriteAppEvent: true,
		OnProgress: func(p zsp.Progress) {
			if p.Phase != "" {
				fmt.Printf("[%s] %s\n", p.Phase, p.Target)
			}
		},
	})
	if err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "already published") {
			fmt.Printf("Notice: release version_code %d is already published on Zapstore (%v). Skipping without error.\n", candidate.VersionCode, err)
			return
		}
		fmt.Fprintf(os.Stderr, "Error publishing to Zapstore: %v\n", err)
		if result != nil {
			fmt.Printf("Partial result: status=%s, id=%s\n", result.Status, result.ID)
		}
		os.Exit(1)
	}

	fmt.Println("=== SUCCESS ===")
	fmt.Printf("Successfully published %s v%s to Zapstore!\n", candidate.AppID, candidate.VersionName)
	fmt.Printf("Status: %s\n", result.Status)
	fmt.Printf("Release Event ID: %s\n", result.ID)
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
