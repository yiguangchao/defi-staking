package main

import (
	"defi-demo/bindings"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// 💾 Database model
type VaultEvent struct {
	gorm.Model
	TxHash      string  `gorm:"index" json:"tx_hash"`
	BlockNumber uint64  `json:"block_number"`
	EventType   string  `json:"event_type"`
	UserAddress string  `json:"user_address"`
	AmountWei   string  `json:"-"`
	AmountHuman float64 `json:"amount_usdt"`
}

var contractAddress = common.HexToAddress("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")

func main() {
	dsn := "host=localhost user=postgres password=123456 dbname=defi_db port=5432 sslmode=disable TimeZone=Asia/Shanghai"
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("❌ Database connection failed: %v", err)
	}
	db.AutoMigrate(&VaultEvent{})

	// Connect to RPC
	client, err := ethclient.Dial("ws://127.0.0.1:8545")
	if err != nil {
		log.Fatal(err)
	}
	// Bind contract
	vault, err := bindings.NewVault(contractAddress, client)
	if err != nil {
		log.Fatal(err)
	}

	// --- 2. Start background threads ---
	// A. Event Listener (Handles real-time deposits/withdrawals)
	go startBlockchainListener(db, client, vault)

	// B. ✅ New: Reconciliation Bot (Fixes data discrepancies)
	go startReconciler(db, vault)

	// --- 3. Start API ---
	r := gin.Default()
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:5173", "http://127.0.0.1:5174"},
		AllowMethods:     []string{"GET", "POST"},
		AllowHeaders:     []string{"Origin", "Content-Type"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	r.GET("/api/events", func(c *gin.Context) {
		var events []VaultEvent
		db.Order("id desc").Find(&events)
		c.JSON(200, gin.H{"code": 200, "data": events})
	})

	// History trend endpoint (For charts)
	r.GET("/api/history", func(c *gin.Context) {
		var events []VaultEvent
		db.Order("id asc").Find(&events)

		type HistoryPoint struct {
			ID     uint    `json:"id"`
			Time   string  `json:"time"`
			TVL    float64 `json:"tvl"`
			Change float64 `json:"change"`
		}
		var history []HistoryPoint
		var currentTVL float64 = 0

		for _, evt := range events {
			// DEPOSIT and YIELD both increase TVL
			if evt.EventType == "DEPOSIT" || evt.EventType == "YIELD" {
				currentTVL += evt.AmountHuman
			} else if evt.EventType == "WITHDRAW" {
				currentTVL -= evt.AmountHuman
			}
			history = append(history, HistoryPoint{
				ID:     evt.ID,
				Time:   evt.CreatedAt.Format("15:04:05"),
				TVL:    currentTVL,
				Change: evt.AmountHuman,
			})
		}
		c.JSON(200, gin.H{"code": 200, "data": history})
	})

	fmt.Println("🚀 API service started on :8080")
	r.Run(":8080")
}

// ---------------------------------------------------------
// 🤖 Core Logic: Reconciler Bot
// ---------------------------------------------------------
func startReconciler(db *gorm.DB, vault *bindings.Vault) {
	fmt.Println("🤖 Reconciler started: Checking on-chain balance every 5 seconds...")

	ticker := time.NewTicker(5 * time.Second)
	for range ticker.C {
		// 1. Ask Chain: How much is actually in the vault? (Source of Truth)
		totalAssetsWei, err := vault.TotalAssets(&bind.CallOpts{Pending: false})
		if err != nil {
			log.Printf("🤖 Reconciliation failed (Chain read error): %v", err)
			continue
		}

		// Convert to float
		chainTVL, _ := new(big.Float).Quo(new(big.Float).SetInt(totalAssetsWei), big.NewFloat(1e18)).Float64()

		// 2. Ask DB: How much have we recorded?
		var totalDeposit, totalWithdraw, totalYield float64
		db.Model(&VaultEvent{}).Where("event_type = ?", "DEPOSIT").Select("COALESCE(SUM(amount_human), 0)").Scan(&totalDeposit)
		db.Model(&VaultEvent{}).Where("event_type = ?", "WITHDRAW").Select("COALESCE(SUM(amount_human), 0)").Scan(&totalWithdraw)
		db.Model(&VaultEvent{}).Where("event_type = ?", "YIELD").Select("COALESCE(SUM(amount_human), 0)").Scan(&totalYield)

		dbTVL := totalDeposit + totalYield - totalWithdraw

		// 3. Find discrepancy: What is the difference?
		// If Chain > DB, it implies invisible yield
		diff := chainTVL - dbTVL

		// Set a tiny ignore threshold (Avoid floating point precision issues)
		if diff > 0.0001 {
			fmt.Printf("🤖 Discrepancy found! Chain: %.4f | DB: %.4f | To reconcile: %.4f\n", chainTVL, dbTVL, diff)

			// 4. Auto-reconcile: Insert a YIELD record
			record := VaultEvent{
				EventType:   "YIELD",                                        // ✅ New type
				UserAddress: "0x0000000000000000000000000000000000000000",   // System auto-recorded
				TxHash:      fmt.Sprintf("AUTO_SYNC_%d", time.Now().Unix()), // Fake a Hash
				BlockNumber: 0,
				AmountWei:   "0", // Simplified handling
				AmountHuman: diff,
			}
			db.Create(&record)
			fmt.Println("✅ Auto-reconciliation complete: Yield recorded")
		}
	}
}

// ---------------------------------------------------------
// 🎧 Previous listener logic (No major changes)
// ---------------------------------------------------------
func startBlockchainListener(db *gorm.DB, client *ethclient.Client, vault *bindings.Vault) {
	// ... Logic remains the same, kept brief here for code completeness ...
	// Ensure full listener code is here during actual runtime

	depositChan := make(chan *bindings.VaultDeposit)
	subDeposit, _ := vault.WatchDeposit(nil, depositChan, nil, nil)

	withdrawChan := make(chan *bindings.VaultWithdraw)
	subWithdraw, _ := vault.WatchWithdraw(nil, withdrawChan, nil, nil, nil)

	fmt.Println("🎧 Event listener started...")

	for {
		select {
		case err := <-subDeposit.Err():
			log.Fatalf("❌ Listener disconnected: %v", err)
		case err := <-subWithdraw.Err():
			log.Fatalf("❌ Listener disconnected: %v", err)
		case event := <-depositChan:
			saveEvent(db, "DEPOSIT", event.Raw.TxHash.Hex(), event.Raw.BlockNumber, event.Owner.Hex(), event.Assets)
		case event := <-withdrawChan:
			saveEvent(db, "WITHDRAW", event.Raw.TxHash.Hex(), event.Raw.BlockNumber, event.Owner.Hex(), event.Assets)
		}
	}
}

func saveEvent(db *gorm.DB, eventType string, txHash string, blockNum uint64, user string, assets *big.Int) {
	amountFloat := new(big.Float).SetInt(assets)
	humanAmount, _ := new(big.Float).Quo(amountFloat, big.NewFloat(1e18)).Float64()

	record := VaultEvent{
		TxHash:      txHash,
		BlockNumber: blockNum,
		EventType:   eventType,
		UserAddress: user,
		AmountWei:   assets.String(),
		AmountHuman: humanAmount,
	}
	// Simple deduplication
	var count int64
	db.Model(&VaultEvent{}).Where("tx_hash = ?", txHash).Count(&count)
	if count == 0 {
		db.Create(&record)
		fmt.Printf("\n💰 [Listener] New Event: %s | %.2f\n", eventType, humanAmount)
	}
}
