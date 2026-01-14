package main

import (
	"defi-demo/bindings"
	"fmt"
	"log"
	"math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/gin-gonic/gin"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// 💾 Define database model (Model)
type DepositRecord struct {
	gorm.Model
	TxHash      string  `gorm:"uniqueIndex" json:"tx_hash"`
	BlockNumber uint64  `json:"block_number"`
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
	db.AutoMigrate(&DepositRecord{})
	fmt.Println("🐘  PostgreSQL connection successful, table structure initialized")

	// --- 2. Start blockchain monitoring (put into backend Goroutine) ---
	go startBlockchainListener(db)

	// --- 3. Start Web API server (Gin) ---
	r := gin.Default()

	// Interface: Query all deposits
	r.GET("/api/deposits", func(c *gin.Context) {
		var records []DepositRecord
		// Query database, ordered by time descending
		result := db.Order("id desc").Find(&records)
		if result.Error != nil {
			c.JSON(500, gin.H{"error": result.Error.Error()})
			return
		}
		// Return JSON
		c.JSON(200, gin.H{
			"code": 200,
			"data": records,
			"msg":  "success",
		})
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

	contractAddress := common.HexToAddress("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")
	vault, err := bindings.NewVault(contractAddress, client)
	if err != nil {
		log.Printf("❌ Contract binding failed: %v", err)
		return
	}

	depositChan := make(chan *bindings.VaultDeposit)
	sub, err := vault.WatchDeposit(&bind.WatchOpts{Context: nil}, depositChan, nil, nil)
	if err != nil {
		log.Printf("❌ Subscription failed: %v", err)
		return
	}
	fmt.Println("🎧 Blockchain listener started in background...")

	for {
		select {
		case err := <-sub.Err():
			log.Printf("❌ Subscription disconnected: %v", err)
		case event := <-depositChan:
			amountFloat := new(big.Float).SetInt(event.Assets)
			humanAmount, _ := new(big.Float).Quo(amountFloat, big.NewFloat(1e18)).Float64()

			record := DepositRecord{
				TxHash:      event.Raw.TxHash.Hex(),
				BlockNumber: event.Raw.BlockNumber,
				UserAddress: event.Owner.Hex(),
				AmountWei:   event.Assets.String(),
				AmountHuman: humanAmount,
			}

			if err := db.Create(&record).Error; err == nil {
				fmt.Printf("\n🐘 [Inbound] User:%s Amount:%.2f\n", record.UserAddress, record.AmountHuman)
			}
		}
	}
}
