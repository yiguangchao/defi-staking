package services

import (
	"context"
	"fmt"
	"log"
	"math/big"
	"sync"
	"time"

	"defi-demo/models"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"gorm.io/gorm"

	"defi-demo/bindings/vault"
)

type Reconciler struct {
	db           *gorm.DB
	client       *ethclient.Client
	contractAddr common.Address
	vaultInst    *vault.Vault // Your contract instance
	mu           sync.Mutex   // Mutex to ensure only one reconciliation process runs at a time
}

// Constructor
func NewReconciler(db *gorm.DB, client *ethclient.Client, addrHex string) (*Reconciler, error) {
	addr := common.HexToAddress(addrHex)
	instance, err := vault.NewVault(addr, client)
	if err != nil {
		return nil, err
	}

	return &Reconciler{
		db:           db,
		client:       client,
		contractAddr: addr,
		vaultInst:    instance,
	}, nil
}

// Start initiates the background inspection task
func (r *Reconciler) Start(ctx context.Context) {
	// Trigger every 5 seconds
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	log.Println("[Reconciler] Started, polling for silent yield every 5 seconds...")

	for {
		select {
		case <-ctx.Done():
			log.Println("[Reconciler] Stop signal received, shutting down gracefully")
			return
		case <-ticker.C:
			// Trigger reconciliation logic
			r.reconcile()
		}
	}
}

// reconcile handles the specific reconciliation and recording logic
func (r *Reconciler) reconcile() {
	// Lock to prevent overlapping reconciliation runs
	r.mu.Lock()
	defer r.mu.Unlock()

	// 1. Fetch real total assets on-chain (On-Chain TVL)
	onChainAssets, err := r.vaultInst.TotalAssets(&bind.CallOpts{})
	if err != nil {
		log.Printf("[Reconciler] Failed to read totalAssets on-chain: %v\n", err)
		return
	}

	// 2. Calculate current Book TVL from the database
	// Logic: Sum of all DEPOSIT and YIELD, minus sum of all WITHDRAW
	bookAssets := r.getBookTVL()

	// 3. Calculate difference Delta = OnChain - Book
	delta := new(big.Int).Sub(onChainAssets, bookAssets)

	// cmp result: > 0 means more funds on-chain, indicating silent yield
	if delta.Cmp(big.NewInt(0)) > 0 {
		log.Printf("[Reconciler] Silent yield detected! Delta: %s Wei\n", delta.String())
		r.recordYield(delta)
	} else if delta.Cmp(big.NewInt(0)) < 0 {
		// Theoretically should not happen, unless exploited. Can trigger an alert here.
		log.Printf("[WARNING] Data inversion! On-chain funds are less than book funds! Delta: %s\n", delta.String())
	}
	// == 0 requires no action
}

// getBookTVL aggregates transaction flow from the database
func (r *Reconciler) getBookTVL() *big.Int {
	var txs []models.VaultTransaction
	r.db.Find(&txs)

	total := big.NewInt(0)
	for _, tx := range txs {
		amt, _ := new(big.Int).SetString(tx.Amount, 10)
		if tx.Type == "DEPOSIT" || tx.Type == "YIELD" {
			total.Add(total, amt) // total += amt
		} else if tx.Type == "WITHDRAW" {
			total.Sub(total, amt) // total -= amt
		}
	}
	return total
}

// recordYield records yield transactions into the database
func (r *Reconciler) recordYield(amount *big.Int) {
	// Generate a virtual TxHash
	virtualHash := fmt.Sprintf("YIELD_%d", time.Now().UnixNano())

	yieldTx := models.VaultTransaction{
		TxHash: virtualHash,
		User:   "SYSTEM",
		Type:   "YIELD",
		Amount: amount.String(),
	}

	// Insert into database
	if err := r.db.Create(&yieldTx).Error; err != nil {
		log.Printf("[Reconciler] Failed to record YIELD entry: %v\n", err)
	} else {
		log.Println("[Reconciler] Successfully recorded yield, TVL data is synchronized")
		// TODO: Send WebSocket notification to frontend to refresh charts
	}
}
