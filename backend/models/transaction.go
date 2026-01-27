package models

import (
	"time"
)

type VaultTransaction struct {
	ID        uint   `gorm:"primaryKey"`
	TxHash    string `gorm:"uniqueIndex"`
	User      string
	Type      string
	Amount    string
	CreatedAt time.Time
}
