import { useState, useEffect } from 'react';
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther, parseEther } from 'viem';
import { VAULT_ADDRESS, VAULT_ABI, ERC20_ABI } from '../constants';

export const VaultInfo = () => {
  // 1. Total Assets
  const { data: totalAssets, refetch: refetchAssets } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'totalAssets',
  });

  // 2. Total Supply
  const { data: totalSupply, refetch: refetchSupply } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'totalSupply',
  });

  // 3. Token address used by this Vault
  const { data: assetAddress } = useReadContract({
    address: VAULT_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'asset',
  });

  // Calculate stock price: If there are no shares, the stock price is 1; Otherwise=Assets/Shares
  const sharePrice = (totalAssets && totalSupply && BigInt(totalSupply.toString()) > 0)
    ? Number(formatEther(BigInt(totalAssets.toString()))) / Number(formatEther(BigInt(totalSupply.toString())))
    : 1.0;

  // --- Logic of simulating returns ---
  const { data: hash, writeContract, isPending, isSuccess } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash });

  // Simulate yield: directly transfer 10 tokens to the Vault without taking shares
  const handleSimulateYield = () => {
    if (!assetAddress) return;
    writeContract({
      address: assetAddress as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'transfer',
      args: [VAULT_ADDRESS, parseEther('10')],
    });
  };

  // Refresh data after successful transaction
  useEffect(() => {
    if (isSuccess) {
      refetchAssets();
      refetchSupply();
    }
  }, [isSuccess, refetchAssets, refetchSupply]);

  return (
    <div style={{ 
      border: '1px solid #3b82f6', 
      padding: '20px', 
      borderRadius: '12px', 
      marginBottom: '20px',
      background: '#eff6ff'
    }}>
      <h3 style={{color: '#1d4ed8', marginTop: 0}}>📈 Vault signboard (Dashboard)</h3>
      
      <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '15px' }}>
        <div>
          <div style={{fontSize: '12px', color: '#666'}}>current stock price (Exchange Rate)</div>
          <div style={{fontSize: '24px', fontWeight: 'bold', color: '#1d4ed8'}}>
            1 Share = {sharePrice.toFixed(4)} USDT
          </div>
        </div>
        <div>
          <div style={{fontSize: '12px', color: '#666'}}>Total assets of the treasury (TVL)</div>
          <div style={{fontSize: '24px', fontWeight: 'bold'}}>
             {totalAssets ? Number(formatEther(BigInt(totalAssets.toString()))).toFixed(2) : '0.00'} USDT
          </div>
        </div>
      </div>

      <div style={{ borderTop: '1px solid #bfdbfe', paddingTop: '15px' }}>
        <button 
          onClick={handleSimulateYield}
          disabled={isPending || isConfirming}
          style={{ 
            width: '100%',
            padding: '10px', 
            background: 'linear-gradient(45deg, #8b5cf6, #ec4899)',
            color: 'white', 
            border: 'none', 
            borderRadius: '6px', 
            cursor: 'pointer',
            fontWeight: 'bold'
          }}
        >
          {isPending || isConfirming ? '💸 Simulating yield...' : '🚀 Simulate 10 USDT yield (Admin Only)'}
        </button>
        <div style={{fontSize: '12px', color: '#666', marginTop: '5px', textAlign: 'center'}}>
          * Click this button to directly "donate" 10 USDT to the vault, increasing all holders' assets
        </div>
      </div>
    </div>
  );
};