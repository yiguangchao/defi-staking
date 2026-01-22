import { useQuery } from '@tanstack/react-query';

// Define data structures (corresponding to JSON in Go backend)
interface VaultEvent {
  ID: number;
  CreatedAt: string;
  tx_hash: string;
  block_number: number;
  event_type: 'DEPOSIT' | 'WITHDRAW' | 'YIELD';
  user_address: string;
  amount_usdt: number;
}
export const EventsTable = () => {
  // Use React Query to automatically manage request status (loading/error/success)
  const { data, isLoading, error } = useQuery({
    queryKey: ['events'], // Cache key
    queryFn: async () => {
      // The fetch here points to the Go API
      const response = await fetch('http://localhost:8080/api/events');
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    },
    // Automatically refresh data every 2 seconds to achieve "real-time" effect
    refetchInterval: 2000,
  });

  if (isLoading) return <div style={{ textAlign: 'center' }}>⏳ Loading data...</div>;
  if (error) return <div style={{ color: 'red' }}>❌ Loading failed: {error.message} (Please check if the Go backend is running)</div>;

  // The data structure returned by the backend is {code: 200, data: [...]}
  const events: VaultEvent[] = data?.data || [];

  return (
    <div style={{ marginTop: '20px', width: '100%' }}>
      <h3>📜 Historical flow (real-time update)</h3>
      {events.length === 0 ? (
        <p>There is no record at the moment, go ahead and save some money!</p>
      ) : (
        <table style={{ width: '100%', borderCollapse: 'collapse', marginTop: '10px' }}>
          <thead>
            <tr style={{ background: '#f0f0f0', textAlign: 'left' }}>
              <th style={{ padding: '8px' }}>type</th>
              <th style={{ padding: '8px' }}>user</th>
              <th style={{ padding: '8px' }}>amount (USDT)</th>
              <th style={{ padding: '8px' }}>block</th>
              <th style={{ padding: '8px' }}>hash</th>
            </tr>
          </thead>
          <tbody>
            {events.map((evt) => (
              <tr key={evt.ID} style={{ borderBottom: '1px solid #eee' }}>
                <td style={{ padding: '8px' }}>
                  <span style={{
                    background:
                      evt.event_type === 'DEPOSIT' ? '#e6fffa' :
                        evt.event_type === 'WITHDRAW' ? '#fff5f5' :
                          '#f3e8ff',
                    color:
                      evt.event_type === 'DEPOSIT' ? '#00bfa5' :
                        evt.event_type === 'WITHDRAW' ? '#e53e3e' :
                          '#9333ea',
                    padding: '4px 8px',
                    borderRadius: '4px',
                    fontWeight: 'bold',
                    fontSize: '12px'
                  }}>
                    {evt.event_type === 'YIELD' ? '💰 Profit (YIELD)' : evt.event_type}
                  </span>
                </td>
                <td style={{ padding: '8px', fontFamily: 'monospace' }}>
                  {evt.user_address.slice(0, 6)}...{evt.user_address.slice(-4)}
                </td>
                <td style={{ padding: '8px', fontWeight: 'bold' }}>
                  {evt.amount_usdt.toFixed(2)}
                </td>
                <td style={{ padding: '8px' }}>{evt.block_number}</td>
                <td style={{ padding: '8px' }}>
                  <a
                    href="#"
                    title={evt.tx_hash}
                    style={{ textDecoration: 'none', color: '#3182ce' }}
                  >
                    🔗
                  </a>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
};