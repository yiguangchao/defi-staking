import { useState, useEffect } from 'react';
import { 
  useWriteContract, 
  useAccount, 
  useWaitForTransactionReceipt, 
  useReadContract 
} from 'wagmi';
import { parseEther, formatEther } from 'viem';
import { VAULT_ADDRESS, VAULT_ABI, ERC20_ABI } from '../../constants';

export const ActionPanel = () => {
  const [amount, setAmount] = useState('');
  const { address } = useAccount();

  // ---------------------------------------------------------
  // 1. First, check what Token (Asset) is used at the bottom of this Vault
  // ---------------------------------------------------------
  const { data: assetAddress } = useReadContract({
    address: VAULT_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'asset',
  });

  // ---------------------------------------------------------
  // 2. Only after getting the Token address can we query the allowance
  // ---------------------------------------------------------
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: assetAddress as `0x${string}`, 
    
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address && assetAddress ? [address, VAULT_ADDRESS] : undefined,
  });

  // Hook for writing contracts
  const { data: hash, writeContract, isPending, error } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  // After successfully monitoring the transaction, refresh the authorization limit
  useEffect(() => {
    if (isSuccess) {
      refetchAllowance();
    }
  }, [isSuccess, refetchAllowance]);

  // ---------------------------------------------------------
  // Business logic: Determine whether the current transaction should be "authorized" or "deposited"
  // ---------------------------------------------------------
  const amountWei = amount ? parseEther(amount) : BigInt(0);
  const currentAllowance = allowance ? BigInt(allowance.toString()) : BigInt(0);
  
  // Do you need authorization? (Input amount>current authorized limit)
  const needsApproval = amountWei > currentAllowance;

  // 🟢 Action A: Approve
  const handleApprove = () => {
    if (!assetAddress || !amount) return;
    writeContract({
      address: assetAddress as `0x${string}`, 
      
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [VAULT_ADDRESS, amountWei], 
    });
  };

  // 🔵 Action B: Deposit
  const handleDeposit = () => {
    if (!amount || !address) return;
    writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [amountWei, address],
    });
  };

  // 🔴 Action C: Withdraw - Withdraw doesn't require approval, because it's dealing with Shares
  const handleWithdraw = () => {
    if (!amount || !address) return;
    writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: 'withdraw',
      args: [amountWei, address, address],
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
      <h3>💸 Financial operations (Approve/Deposit)</h3>
      
      {/* Debug information: see the underlying token address */}
      <div style={{fontSize: '12px', color: '#999', marginBottom: '10px'}}>
        Token Address: {assetAddress ? assetAddress.toString().slice(0,10) + "..." : "Loading..."} <br/>
        Current Allowance: {allowance ? formatEther(BigInt(allowance.toString())) : "0"}
      </div>

      <div style={{ display: 'flex', gap: '10px', marginBottom: '10px' }}>
        <input
          type="number"
          placeholder="Enter the amount (e.g. 5.0)"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          style={{ padding: '10px', borderRadius: '6px', border: '1px solid #ccc', flex: 1 }}
        />
      </div>

      <div style={{ display: 'flex', gap: '10px' }}>
        
        {/* 🔥 Smart button: Automatically switch between Approve/Deposit*/}
        {needsApproval ? (
          <button 
            onClick={handleApprove}
            disabled={isPending || isConfirming || !amount}
            style={{ padding: '10px 20px', background: '#f59e0b', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', opacity: (isPending || !amount) ? 0.5 : 1 }}
          >
            {isPending ? 'Authorizing...' : '🔐 1. Click on authorization (Approve)'}
          </button>
        ) : (
          <button 
            onClick={handleDeposit}
            disabled={isPending || isConfirming || !amount}
            style={{ padding: '10px 20px', background: '#10b981', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', opacity: (isPending || !amount) ? 0.5 : 1 }}
          >
            {isPending ? 'Deposit in progress ..' : '📥 2. Deposit into the vault (Deposit)'}
          </button>
        )}

        {/* Withdraw button is always visible */}
        <button 
          onClick={handleWithdraw}
          disabled={isPending || isConfirming || !amount}
          style={{ padding: '10px 20px', background: '#ef4444', color: 'white', border: 'none', borderRadius: '6px', cursor: 'pointer', opacity: (isPending || !amount) ? 0.5 : 1 }}
        >
          {isPending ? 'Signing...' : '📤 Withdraw'}
        </button>
      </div>

      {isConfirming && <div style={{ marginTop: '10px', color: 'orange' }}>⏳ Transaction confirming...</div>}
      {isSuccess && <div style={{ marginTop: '10px', color: 'green' }}>✅ Transaction successful!</div>}
      {error && <div style={{ marginTop: '10px', color: 'red', fontSize: '12px' }}>❌ error: {error.message.split('\n')[0]}</div>}
    </div>
  );
};