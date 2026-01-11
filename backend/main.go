package main

import (
	"context"
	"defi-demo/bindings"
	"fmt"
	"log"

	// "math/big"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// 1.connect to an Ethereum node
	rpcUrl := "https://eth-mainnet.g.alchemy.com/v2/e8WW1ln1MXAyRT8rWjPpg"
	client, err := ethclient.Dial(rpcUrl)
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}
	fmt.Println("Connected to Ethereum node")

	// 2.Prepare contract address
	contractAddress := common.HexToAddress("")

	vault, err := bindings.NewVault(contractAddress, client)
	if err != nil {
		log.Fatalf("Failed to instantiate vault contract: %v", err)
	}

	// 3.Define query scope
	header, err := client.HeaderByNumber(context.Background(), nil)
	if err != nil {
		log.Fatalf("Failed to get latest block header: %v", err)
	}
	if header == nil {
		log.Fatalf("Failed to get latest block header")
	}
	currentBlock := header.Number.Uint64()
	startBlock := currentBlock - 1000

	fmt.Printf("Querying events from block %d to %d\n", startBlock, currentBlock)

	filterOpts := &bind.FilterOpts{
		Start:   startBlock,
		End:     &currentBlock,
		Context: context.Background(),
	}

	// 4. Call the Filter Deposit method bound to the contract
	iterator, err := vault.FilterDeposit(filterOpts, nil, nil)
	if err != nil {
		fmt.Printf("Failed to filter Deposit events: %v\n", err)
		return
	}

	// 5. Iterate through the events
	found := false
	for iterator.Next() {
		found = true
		event := iterator.Event
		fmt.Printf("💰 [New deposit discovery!] \n")
		fmt.Printf("   User: %s\n", event.Owner.Hex())
		fmt.Printf("   Amount: %s (Wei)\n", event.Assets.String())
		fmt.Printf("   Shares: %s\n", event.Shares.String())
		fmt.Println("------------------------------------------------")
	}

	if !found {
		fmt.Println("No Deposit events found in the specified block range.")
	}
}
