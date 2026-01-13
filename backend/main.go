package main

import (
	"defi-demo/bindings"
	"fmt"
	"log"
	"math/big"
	"os"
	"os/signal"
	"syscall"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// 💾 Define database model (Model)
type DepositRecord struct {
	gorm.Model
	TxHash      string `gorm:"uniqueIndex"`
	BlockNumber uint64
	UserAddress string
	AmountWei   string
	AmountHuman float64
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

	// --- 2. Connect to WebSocket nodes ---
	client, err := ethclient.Dial("ws://127.0.0.1:8545")
	if err != nil {
		log.Fatalf("❌ Chain connection failed: %v", err)
	}
	fmt.Println("✅ WebSocket connected")

	// --- 3. Binding contract ---
	// ⚠️ Make sure this is the address where your cast send was successful just now
	contractAddress := common.HexToAddress("0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0")
	vault, err := bindings.NewVault(contractAddress, client)
	if err != nil {
		log.Fatalf("❌ Contract binding failed: %v", err)
	}

	// --- 4. start listening ---
	depositChan := make(chan *bindings.VaultDeposit)
	sub, err := vault.WatchDeposit(&bind.WatchOpts{Context: nil}, depositChan, nil, nil)
	if err != nil {
		log.Fatalf("❌ Subscription failed: %v", err)
	}
	fmt.Println("🎧 Monitoring for new deposit events and preparing to write to the database...")

	// --- 5. handle incidents ---
	go func() {
		for {
			select {
			case err := <-sub.Err():
				log.Fatalf("❌ Subscription disconnected: %v", err)
			case event := <-depositChan:
				// Calculate human readable amounts
				amountFloat := new(big.Float).SetInt(event.Assets)
				humanAmount, _ := new(big.Float).Quo(amountFloat, big.NewFloat(1e18)).Float64()

				// 📦 Build a record object
				record := DepositRecord{
					TxHash:      event.Raw.TxHash.Hex(),
					BlockNumber: event.Raw.BlockNumber,
					UserAddress: event.Owner.Hex(),
					AmountWei:   event.Assets.String(),
					AmountHuman: humanAmount,
				}

				// 💾 store in the database
				result := db.Create(&record)
				if result.Error != nil {
					log.Printf("⚠️ Save failed (possibly due to duplicate transactions): %v", result.Error)
				} else {
					fmt.Printf("\n💾 [Storage successful] User: %s | amount: %.2f USDT | Block: %d\n",
						record.UserAddress, record.AmountHuman, record.BlockNumber)
				}
			}
		}
	}()

	// --- 6. Elegant Exit ---
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	fmt.Println("👋 Program exit")
}
