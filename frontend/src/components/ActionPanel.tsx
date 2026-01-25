import { useState, useEffect } from 'react';
import { 
  useWriteContract, 
  useAccount, 
  useWaitForTransactionReceipt, 
  useReadContract,
  useBalance 
} from 'wagmi';
import { parseEther, formatEther } from 'viem';
import toast from 'react-hot-toast';
import { VAULT_ADDRESS, VAULT_ABI, ERC20_ABI } from '../../constants';

export const ActionPanel = () => {
  const [amount, setAmount] = useState('');
  const { address } = useAccount();

  // 1. Read underlying Token address
  const { data: assetAddress } = useReadContract({
    address: VAULT_ADDRESS,
    abi: ERC20_ABI,
    functionName: 'asset',
  });

  // 2. Read Token allowance
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: assetAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address && assetAddress ? [address, VAULT_ADDRESS] : undefined,
  });

  // 3. ✅ New: Read user's token balance in wallet (for Max button)
  const { data: userBalance, refetch: refetchBalance } = useReadContract({
    address: assetAddress as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // 4. ✅ New: Read user's share balance in Vault (for Withdraw Max)
  const { data: userShares, refetch: refetchShares } = useReadContract({
    address: VAULT_ADDRESS,
    abi: VAULT_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  // Contract write hook
  const { data: hash, writeContract, isPending, error } = useWriteContract();
  
  // Wait for transaction receipt
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // --- 🌟 Core Logic: State monitoring and toast notifications ---
  useEffect(() => {
    if (isConfirming) {
      toast.loading('⛓️ Confirming transaction...', { id: 'tx-toast' });
    }
    if (isSuccess) {
      toast.success('✅ Transaction successful!', { id: 'tx-toast' });
      setAmount(''); // Clear input field
      // Refetch all data
      refetchAllowance();
      refetchBalance();
      refetchShares();
    }
    if (error) {
      toast.error(`❌ Failed: ${(error as any).shortMessage || error.message}`, { id: 'tx-toast' });
    }
  }, [isConfirming, isSuccess, error, refetchAllowance, refetchBalance, refetchShares]);

  // --- Business Logic Calculations ---
  const amountWei = amount ? parseEther(amount) : BigInt(0);
  const currentAllowance = allowance ? BigInt(allowance.toString()) : BigInt(0);
  const currentBalance = userBalance ? BigInt(userBalance.toString()) : BigInt(0);
  
  const needsApproval = amountWei > currentAllowance;
  // Insufficient balance validation
  const isInsufficientBalance = amountWei > currentBalance;

  // --- Button Handlers ---
  const handleMax = () => {
    if (userBalance) {
      setAmount(formatEther(BigInt(userBalance.toString())));
    }
  };

  const handleApprove = () => {
    if (!assetAddress || !amount) return;
    writeContract({
      address: assetAddress as `0x${string}`,
      abi: ERC20_ABI,
      functionName: 'approve',
      args: [VAULT_ADDRESS, amountWei],
    });
  };

  const handleDeposit = () => {
    if (!amount || !address) return;
    if (isInsufficientBalance) {
      toast.error('💸 Insufficient balance!');
      return;
    }
    writeContract({
      address: VAULT_ADDRESS,
      abi: VAULT_ABI,
      functionName: 'deposit',
      args: [amountWei, address],
    });
  };

  const handleWithdraw = () => {
    if (!amount || !address) return;
    // Simple withdrawal logic (No strict share validation, for demo purposes)
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
      background: 'white',
      boxShadow: '0 4px 6px -1px rgba(0, 0, 0, 0.1)'
    }}>
      <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px'}}>
        <h3 style={{margin: 0}}>💸 Fund Operations</h3>
        <span style={{fontSize: '12px', color: '#64748b'}}>
          Balance: {userBalance ? Number(formatEther(BigInt(userBalance.toString()))).toFixed(4) : '0.00'}
        </span>
      </div>

      <div style={{ display: 'flex', gap: '10px', marginBottom: '15px' }}>
        <div style={{position: 'relative', flex: 1}}>
          <input
            type="number"
            placeholder="0.0"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            style={{ 
              width: '100%',
              padding: '12px', 
              paddingRight: '60px',
              borderRadius: '8px', 
              border: '1px solid #cbd5e1',
              fontSize: '16px',
              boxSizing: 'border-box'
            }}
          />
          {/* MAX button (Absolute positioned inside the input) */}
          <button
            onClick={handleMax}
            style={{
              position: 'absolute',
              right: '8px',
              top: '50%',
              transform: 'translateY(-50%)',
              background: '#e0f2fe',
              color: '#0284c7',
              border: 'none',
              borderRadius: '4px',
              padding: '4px 8px',
              fontSize: '12px',
              fontWeight: 'bold',
              cursor: 'pointer'
            }}
          >
            MAX
          </button>
        </div>
      </div>

      <div style={{ display: 'flex', gap: '10px' }}>
        {needsApproval ? (
          <button 
            onClick={handleApprove}
            disabled={isPending || isConfirming || !amount}
            style={{ 
              flex: 1, padding: '12px', background: '#f59e0b', color: 'white', 
              border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold',
              opacity: (isPending || !amount) ? 0.5 : 1
            }}
          >
            {isPending ? '⏳ Approving...' : '🔐 Approve'}
          </button>
        ) : (
          <button 
            onClick={handleDeposit}
            disabled={isPending || isConfirming || !amount || isInsufficientBalance}
            style={{ 
              flex: 1, padding: '12px', 
              background: isInsufficientBalance ? '#94a3b8' : '#10b981', 
              color: 'white', border: 'none', borderRadius: '8px', 
              cursor: isInsufficientBalance ? 'not-allowed' : 'pointer', fontWeight: 'bold',
              opacity: (isPending || !amount) ? 0.5 : 1
            }}
          >
            {isPending ? '⏳ Depositing...' : isInsufficientBalance ? 'Insufficient Balance' : '📥 Deposit'}
          </button>
        )}

        <button 
          onClick={handleWithdraw}
          disabled={isPending || isConfirming || !amount}
          style={{ 
            flex: 1, padding: '12px', background: '#ef4444', color: 'white', 
            border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold',
            opacity: (isPending || !amount) ? 0.5 : 1
          }}
        >
          {isPending ? '⏳ Withdrawing...' : '📤 Withdraw'}
        </button>
      </div>
    </div>
  );
};