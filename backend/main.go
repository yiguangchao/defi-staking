package main

import (
	"context"
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
	TxHash      string `gorm:"index" json:"tx_hash"`
	BlockNumber uint64 `json:"block_number"`

	BlockHash   string `json:"block_hash"`
	ParentHash  string `json:"parent_hash"`
	IsConfirmed bool   `json:"is_confirmed"`

	EventType   string  `json:"event_type"`
	UserAddress string  `json:"user_address"`
	AmountWei   string  `json:"-"`
	AmountHuman float64 `json:"amount_usdt"`
}

type UserReward struct {
	UserAddress string    `gorm:"primaryKey" json:"user_address"` // Wallet address
	Points      float64   `json:"points"`                         // Calculated points
	UpdatedAt   time.Time `json:"last_updated"`
}

var contractAddress = common.HexToAddress("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")

func main() {
	dsn := "host=localhost user=postgres password=123456 dbname=defi_db port=5432 sslmode=disable TimeZone=Asia/Tokyo"
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("❌ Database connection failed: %v", err)
	}
	db.AutoMigrate(&VaultEvent{}, &UserReward{})

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
	// go startBlockchainListener(db, client, vault)

	go startBlockScanner(db, client, vault)

	// B. ✅ New: Reconciliation Bot (Fixes yield data)
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

// ---------------------------------------------------------
// 🚀 New Core Logic: High-Performance Block Scanner (with Reorg Handling)
// ---------------------------------------------------------
func startBlockScanner(db *gorm.DB, client *ethclient.Client, vault *bindings.Vault) {
	fmt.Println("🚀 Block Scanner Started...")
	ticker := time.NewTicker(2 * time.Second)

	const ConfirmationDepth = 6

	for range ticker.C {
		// 1. Get the latest block height on the chain
		latestHeader, err := client.HeaderByNumber(context.Background(), nil)
		if err != nil {
			continue
		}
		chainHead := latestHeader.Number.Uint64()

		// 2. Get the last synced block height from the database
		var lastEvent VaultEvent
		db.Order("block_number desc").First(&lastEvent)

		targetBlock := lastEvent.BlockNumber + 1
		if lastEvent.BlockNumber == 0 {
			targetBlock = chainHead
		}

		if targetBlock > chainHead {
			continue // Already synced to the latest, wait for new blocks
		}

		// 3. ✨ Core Logic: Get target block info and perform Reorg check ✨
		targetHeader, err := client.HeaderByNumber(context.Background(), big.NewInt(int64(targetBlock)))
		if err != nil {
			continue
		}

		// Check: Is the "Parent Hash" of the current target block equal to the "Hash of the previous block" in the database?
		if lastEvent.BlockNumber > 0 && targetHeader.ParentHash.Hex() != lastEvent.BlockHash {
			fmt.Printf("⚠️ CRITICAL WARNING: On-chain Reorg detected! Target Block %d\n", targetBlock)
			fmt.Printf("   On-chain Parent Hash: %s\n", targetHeader.ParentHash.Hex())
			fmt.Printf("   Local Recorded Hash: %s\n", lastEvent.BlockHash)

			// Execute rollback: Delete the inconsistent previous block data in the database
			db.Where("block_number = ?", lastEvent.BlockNumber).Delete(&VaultEvent{})
			fmt.Printf("   ✅ Rolled back data for block %d, preparing to rescan...\n", lastEvent.BlockNumber)
			continue // The next loop will rescan lastEvent.BlockNumber
		}

		// 4. Hashes match, start processing the contract logs (Events) for this block
		// FilterLogs here will fetch all Deposits/Withdrawals within this block
		processLogsInBlock(db, client, vault, targetBlock, targetHeader.Hash().Hex(), targetHeader.ParentHash.Hex(), chainHead)
	}
}

// ---------------------------------------------------------
// 📦 Helper Function: Parse logs for a specific block and save to database
// ---------------------------------------------------------
func processLogsInBlock(db *gorm.DB, client *ethclient.Client, vault *bindings.Vault, blockNum uint64, blockHash string, parentHash string, chainHead uint64) {
	// ✅ Calculate if it's a "confirmed" secure block
	isConfirmed := (chainHead - blockNum) >= 6

	// Build filter conditions: query data only for this specific block
	filterOpts := &bind.FilterOpts{
		Start:   blockNum,
		End:     &blockNum,
		Context: context.Background(),
	}

	// 1. Fetch Deposit events within this block
	depIter, err := vault.FilterDeposit(filterOpts, nil, nil)
	if err == nil {
		for depIter.Next() {
			event := depIter.Event
			saveEventData(db, "DEPOSIT", event.Raw.TxHash.Hex(), blockNum, blockHash, parentHash, isConfirmed, event.Owner.Hex(), event.Assets)
		}
	}

	// 2. Fetch Withdraw events within this block
	withIter, err := vault.FilterWithdraw(filterOpts, nil, nil, nil)
	if err == nil {
		for withIter.Next() {
			event := withIter.Event
			saveEventData(db, "WITHDRAW", event.Raw.TxHash.Hex(), blockNum, blockHash, parentHash, isConfirmed, event.Owner.Hex(), event.Assets)
		}
	}

	// Print progress in the terminal for monitoring
	status := "🟡 Pending (Unconfirmed)"
	if isConfirmed {
		status = "🟢 Confirmed"
	}
	fmt.Printf("📦 Synced block %d completed [%s]\n", blockNum, status)
}

// ---------------------------------------------------------
// 💾 Helper Function: Save cleaned data into PostgreSQL
// ---------------------------------------------------------
func saveEventData(db *gorm.DB, eventType string, txHash string, blockNum uint64, blockHash string, parentHash string, isConfirmed bool, user string, assets *big.Int) {
	// Amount conversion Wei -> USDT (Human Readable)
	amountFloat := new(big.Float).SetInt(assets)
	humanAmount, _ := new(big.Float).Quo(amountFloat, big.NewFloat(1e18)).Float64()

	// Build database record
	record := VaultEvent{
		TxHash:      txHash,
		BlockNumber: blockNum,
		BlockHash:   blockHash,
		ParentHash:  parentHash,
		IsConfirmed: isConfirmed,
		EventType:   eventType,
		UserAddress: user,
		AmountWei:   assets.String(),
		AmountHuman: humanAmount,
	}

	// Deduplication logic: On-chain transaction replacement may occur, ensure database uniqueness
	var count int64
	db.Model(&VaultEvent{}).Where("tx_hash = ? AND event_type = ?", txHash, eventType).Count(&count)
	if count == 0 {
		db.Create(&record)
		statusIcon := "⏳"
		if isConfirmed {
			statusIcon = "✅"
		}
		fmt.Printf("\n💰 [Scanner] Saved new data: %s | USDT: %.2f | Status: %s\n", eventType, humanAmount, statusIcon)
	}
}

// ---------------------------------------------------------
// 🧮 Core Logic: Off-chain Reward Engine (Liquidity Mining)
// ---------------------------------------------------------
func startRewardEngine(db *gorm.DB, client *ethclient.Client) {
	fmt.Println("🧮 Reward Engine started: Calculating user points...")

	ticker := time.NewTicker(10 * time.Second) // Run every 10 seconds
	for range ticker.C {
		calculateAllRewards(db, client)
	}
}

func calculateAllRewards(db *gorm.DB, client *ethclient.Client) {
	// 1. Get current chain height (to calculate points up to NOW)
	header, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		log.Printf("🧮 Failed to get latest block: %v", err)
		return
	}
	currentBlock := header.Number.Uint64()

	// 2. Find all unique users who have ever interacted
	var userAddresses []string
	db.Model(&VaultEvent{}).Distinct("user_address").Pluck("user_address", &userAddresses)

	// 3. Iterate through each user and calculate their score
	for _, address := range userAddresses {
		if address == "" || address == "0x0000000000000000000000000000000000000000" {
			continue
		}
		points := calculateUserPoints(db, address, currentBlock)

		// 4. Update the DB
		reward := UserReward{
			UserAddress: address,
			Points:      points,
			UpdatedAt:   time.Now(),
		}
		db.Save(&reward) // Insert or Update
	}

	fmt.Printf("🧮 Points updated for %d users at block %d\n", len(userAddresses), currentBlock)
}

// 🧠 The Math: Replay history to calculate "Balance * Duration"
func calculateUserPoints(db *gorm.DB, userAddress string, currentBlock uint64) float64 {
	var events []VaultEvent
	// Fetch all user events ordered by time (block number)
	db.Where("user_address = ?", userAddress).Order("block_number asc").Find(&events)

	var totalPoints float64 = 0
	var currentBalance float64 = 0
	var lastBlock uint64 = 0

	for _, event := range events {
		// Initialize start block
		if lastBlock == 0 {
			lastBlock = event.BlockNumber
		}

		// Calculate duration since last event
		blockDelta := float64(event.BlockNumber - lastBlock)

		// Accumulate points: Balance * Duration
		if blockDelta > 0 {
			totalPoints += currentBalance * blockDelta
		}

		// Update balance based on event type
		if event.EventType == "DEPOSIT" {
			currentBalance += event.AmountHuman
		} else if event.EventType == "WITHDRAW" {
			currentBalance -= event.AmountHuman
			if currentBalance < 0 {
				currentBalance = 0 // Safety check
			}
		}

		// Move time forward
		lastBlock = event.BlockNumber
	}

	// Calculate points from the LAST event until NOW (Pending points)
	if currentBlock > lastBlock && currentBalance > 0 {
		blockDelta := float64(currentBlock - lastBlock)
		totalPoints += currentBalance * blockDelta
	}

	return totalPoints
}
