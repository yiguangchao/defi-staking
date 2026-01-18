import { useState } from 'react';
import { useWriteContract, useAccount, useWaitForTransactionReceipt } from 'wagmi';
import { parseEther } from 'viem';
import { VAULT_ADDRESS, VAULT_ABI } from '../../constants';

export const ActionPanel = () => {
  const [amount, setAmount] = useState('');
  const { address } = useAccount(); // Get the address of the currently connected wallet
  const { data: hash, writeContract, isPending, error } = useWriteContract();

  // Monitor whether the transaction is confirmed to be on chain
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  // Processing deposits
  const handleDeposit = () => {
    if (!amount || !address) return;
    writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [parseEther(amount), address],
    });
  };

  // Processing withdrawals
  const handleWithdraw = () => {
    if (!amount || !address) return;
    writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: 'withdraw',
      args: [parseEther(amount), address, address],
    });
  };

  return (
    <div style={{ 
      border: '1px solid #e2e8f0', 
      padding: '20px', 
      borderRadius: '12px',
      marginBottom: '20px',
      background: 'white'
    }}>
      <h3>💸 Financial operations</h3>
      
      <div style={{ display: 'flex', gap: '10px', marginBottom: '10px' }}>
        <input
          type="number"
          placeholder="Enter amount (e.g., 5.0)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          style={{ 
            padding: '10px', 
            borderRadius: '6px', 
            border: '1px solid #ccc',
            flex: 1 
          }}
        />
      </div>

      <div style={{ display: 'flex', gap: '10px' }}>
        <button 
          onClick={handleDeposit}
          disabled={isPending || isConfirming}
          style={{ 
            padding: '10px 20px', 
            background: '#10b981',
            color: 'white', 
            border: 'none', 
            borderRadius: '6px',
            cursor: 'pointer',
            opacity: (isPending || isConfirming) ? 0.5 : 1
          }}
        >
          {isPending ? 'Wallet signing...' : '📥 Deposit (Deposit)'}
        </button>

        <button 
          onClick={handleWithdraw}
          disabled={isPending || isConfirming}
          style={{ 
            padding: '10px 20px', 
            background: '#ef4444',
            color: 'white', 
            border: 'none', 
            borderRadius: '6px',
            cursor: 'pointer',
            opacity: (isPending || isConfirming) ? 0.5 : 1
          }}
        >
          {isPending ? 'Wallet signing...' : '📤 Withdraw (Withdraw)'}
        </button>
      </div>

      {/* Status prompt */}
      {isConfirming && <div style={{ marginTop: '10px', color: 'orange' }}>⏳ Transaction confirming, please wait...</div>}
      {isSuccess && <div style={{ marginTop: '10px', color: 'green' }}>✅ Transaction successful! Please check the list below for updates</div>}
      {error && <div style={{ marginTop: '10px', color: 'red', fontSize: '12px' }}>❌ Error: {error.message.split('\n')[0]}</div>}
    </div>
  );
};