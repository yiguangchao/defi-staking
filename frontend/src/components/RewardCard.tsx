import { useState, useEffect } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from 'wagmi';
import { formatEther } from 'viem';
import toast from 'react-hot-toast';
import { DISTRIBUTOR_ADDRESS, DISTRIBUTOR_ABI } from '../constants';

export const RewardCard = () => {
  const { address } = useAccount();
  const [proofData, setProofData] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  // Write contract hooks
  const { data: hash, writeContract, isPending, error: writeError } = useWriteContract();
  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({ hash });

  // 1. Query backend API to obtain proof
  const fetchProof = async () => {
    if (!address) return;
    setLoading(true);
    try {
      const res = await fetch(`http://localhost:8080/api/rewards/proof?user=${address}`);
      const data = await res.json();
      
      if (data.code === 200 && data.amount) {
        setProofData(data); // Obtained Proof and Amount
      } else {
        setProofData(null);
      }
    } catch (err) {
      console.error("API Error:", err);
      toast.error("Unable to obtain reward data");
    } finally {
      setLoading(false);
    }
  };

  // Monitor address changes and automatically query
  useEffect(() => {
    fetchProof();
  }, [address]);

  // Monitor transaction status
  useEffect(() => {
    if (isConfirming) toast.loading('🎁 Receiving rewards...', { id: 'claim' });
    if (isSuccess) {
      toast.success('🎉 Claim successful! Rewards have been received', { id: 'claim' });
      setProofData(null); // Clear status to prevent duplicate receipts
    }
    if (writeError) toast.error(`❌ Failed: ${(writeError as any).shortMessage || writeError.message}`, { id: 'claim' });
  }, [isConfirming, isSuccess, writeError]);

  // 2. Initiate a claim transaction
  const handleClaim = () => {
    if (!proofData || !address) return;
    
    writeContract({
      address: DISTRIBUTOR_ADDRESS as `0x${string}`,
      abi: DISTRIBUTOR_ABI,
      functionName: 'claim',
      args: [
        BigInt(proofData.amount),
        proofData.proof
      ],
    });
  };

  if (!address) return null;

  return (
    <div style={{ 
      border: '1px solid #fcd34d', 
      background: '#fffbeb', 
      padding: '20px', 
      borderRadius: '12px', 
      marginBottom: '20px',
      boxShadow: '0 4px 6px -1px rgba(251, 191, 36, 0.2)'
    }}>
      <h3 style={{ margin: '0 0 10px 0', color: '#b45309' }}>🎁 Loyalty rewards (Merkle Drop)</h3>
      
      {loading ? (
        <p>🔄 Calculating your points...</p>
      ) : proofData ? (
        <div>
          <div style={{ fontSize: '24px', fontWeight: 'bold', color: '#d97706', marginBottom: '10px' }}>
            {formatEther(BigInt(proofData.amount))} RWD
          </div>
          <button
            onClick={handleClaim}
            disabled={isPending || isConfirming}
            style={{
              width: '100%',
              padding: '12px',
              background: '#f59e0b',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: 'bold',
              cursor: 'pointer',
              opacity: isPending ? 0.7 : 1
            }}
          >
            {isPending ? '⏳ Signing transaction...' : '💰 Claim Rewards'}
          </button>
        </div>
      ) : (
        <p style={{ color: '#92400e' }}>No rewards available to claim. Try depositing more funds!</p>
      )}
    </div>
  );
};