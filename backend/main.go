package main

import (
	"defi-demo/bindings"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// 💾 Define database model (Model)
type VaultEvent struct {
	gorm.Model
	TxHash      string  `gorm:"uniqueIndex" json:"tx_hash"`
	BlockNumber uint64  `json:"block_number"`
	EventType   string  `json:"event_type"`
	UserAddress string  `json:"user_address"`
	AmountWei   string  `json:"-"`
	AmountHuman float64 `json:"amount_usdt"`
}

func main() {
	// --- 1. Initialize database (SQLite) ---
	dsn := "host=localhost user=postgres password=123456 dbname=defi_db port=5432 sslmode=disable TimeZone=Asia/Shanghai"

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		log.Fatalf("❌ PostgreSQL connection failed: %v\n(Please check if the account password on line 35 of main.go is correct)", err)
	}
	// Auto Migration Mode - Similar to Hibernate's ddl auto
	db.AutoMigrate(&VaultEvent{})
	fmt.Println("🐘  PostgreSQL connection successful, table structure initialized")

	// --- 2. Start blockchain monitoring (put into backend Goroutine) ---
	go startBlockchainListener(db)

	// --- 3. Start Web API server (Gin) ---
	r := gin.Default()

	// Configure CORS middleware (allowing cross domain)
	r.Use(cors.New(cors.Config{
		AllowOrigins:     []string{"http://localhost:5173", "http://localhost:5174", "http://localhost:5175"},
		AllowMethods:     []string{"GET", "POST"},
		AllowHeaders:     []string{"Origin", "Content-Type"},
		ExposeHeaders:    []string{"Content-Length"},
		AllowCredentials: true,
	}))

	// Interface: Query all deposits
	r.GET("/api/events", func(c *gin.Context) {
		var events []VaultEvent
		// Order by time descending
		db.Order("id desc").Find(&events)
		c.JSON(200, gin.H{"code": 200, "data": events})
	})

	// Interface: Query current TVL (Total Value Locked = Total Deposit - Total Withdraw)
	r.GET("/api/tvl", func(c *gin.Context) {
		var totalDeposit, totalWithdraw float64
		// select sum(amount_human) from vault_events where event_type = 'DEPOSIT'
		db.Model(&VaultEvent{}).Where("event_type = ?", "DEPOSIT").Select("COALESCE(SUM(amount_human), 0)").Scan(&totalDeposit)
		db.Model(&VaultEvent{}).Where("event_type = ?", "WITHDRAW").Select("COALESCE(SUM(amount_human), 0)").Scan(&totalWithdraw)

		tvl := totalDeposit - totalWithdraw
		c.JSON(200, gin.H{
			"tvl":            tvl,
			"total_deposit":  totalDeposit,
			"total_withdraw": totalWithdraw,
		})
	})

	r.GET("/api/history", func(c *gin.Context) {
		var events []VaultEvent
		//Arrange in positive order by ID (from morning till night) for easy calculation and accumulation
		db.Order("id asc").Find(&events)

		// Define the return data structure
		type HistoryPoint struct {
			ID     uint    `json:"id"`
			Time   string  `json:"time"`
			TVL    float64 `json:"tvl"`
			Change float64 `json:"change"` // This transaction changed by how much
		}

		var history []HistoryPoint
		var currentTVL float64 = 0

		// 🧠 Core algorithm: replay history (Replay)
		for _, evt := range events {
			// Accumulated calculation
			if evt.EventType == "DEPOSIT" {
				currentTVL += evt.AmountHuman
			} else if evt.EventType == "WITHDRAW" {
				currentTVL -= evt.AmountHuman
			}

			// Record the status of this moment
			history = append(history, HistoryPoint{
				ID:     evt.ID,
				Time:   evt.CreatedAt.Format("15:04:05"),
				TVL:    currentTVL,
				Change: evt.AmountHuman,
			})
		}

		c.JSON(200, gin.H{"code": 200, "data": history})
	})

	fmt.Println("🚀 API Service started, listening port :8080")
	r.Run(":8080")
}

// Independent listener function
func startBlockchainListener(db *gorm.DB) {
	client, err := ethclient.Dial("ws://127.0.0.1:8545")
	if err != nil {
		log.Printf("❌ Chain connection failed: %v", err)
		return
	}

	// ⚠️ Confirm contract address
	contractAddress := common.HexToAddress("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")
	vault, err := bindings.NewVault(contractAddress, client)
	if err != nil {
		log.Printf("❌ Contract binding failed: %v", err)
		return
	}

	// ✅ Channel 1: Deposit Event
	depositChan := make(chan *bindings.VaultDeposit)
	subDeposit, err := vault.WatchDeposit(&bind.WatchOpts{Context: nil}, depositChan, nil, nil)
	if err != nil {
		log.Printf("❌ Deposit subscription failed: %v", err)
		return
	}

	// ✅ Channel 2: Withdrawal Event (New!)
	withdrawChan := make(chan *bindings.VaultWithdraw)
	subWithdraw, err := vault.WatchWithdraw(&bind.WatchOpts{Context: nil}, withdrawChan, nil, nil, nil)
	if err != nil {
		log.Printf("❌ Withdrawal subscription failed: %v", err)
		return
	}

	fmt.Println("🎧 Dual channel monitoring start: waiting for [Deposit] or [Withdrawal]...")

	for {
		select {
		case err := <-subDeposit.Err():
			log.Fatalf("❌ Deposit subscription abnormal disconnection (program exit): %v", err)
		case err := <-subWithdraw.Err():
			log.Fatalf("❌ Withdraw subscription abnormal disconnection (program exit): %v", err)

		// 💰 Processing deposits
		case event := <-depositChan:
			saveEvent(db, "DEPOSIT", event.Raw.TxHash, event.Raw.BlockNumber, event.Owner, event.Assets)

		// 💸 Processing withdrawals
		case event := <-withdrawChan:
			saveEvent(db, "WITHDRAW", event.Raw.TxHash, event.Raw.BlockNumber, event.Owner, event.Assets)
		}
	}
}

func saveEvent(db *gorm.DB, eventType string, rawLog common.Hash, blockNum uint64, user common.Address, assets *big.Int) {
	amountFloat := new(big.Float).SetInt(assets)
	humanAmount, _ := new(big.Float).Quo(amountFloat, big.NewFloat(1e18)).Float64()

	record := VaultEvent{
		TxHash:      rawLog.Hex(),
		BlockNumber: blockNum,
		EventType:   eventType,
		UserAddress: user.Hex(),
		AmountWei:   assets.String(),
		AmountHuman: humanAmount,
	}

	if err := db.Create(&record).Error; err == nil {
		emoji := "💰"
		if eventType == "WITHDRAW" {
			emoji = "💸"
		}
		fmt.Printf("\n%s [New Event Storage] Type:%s | user:%s | amount:%.2f\n", emoji, eventType, record.UserAddress, record.AmountHuman)
	} else {
		log.Printf("Failed to put in storage: %v", err)
	}
}
