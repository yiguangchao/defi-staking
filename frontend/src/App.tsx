import { ConnectButton } from '@rainbow-me/rainbowkit';

function App() {
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '50px',
      fontFamily: 'sans-serif'
    }}>
      <h1>🏦 My DeFi Vault</h1>
      <p>Web3 Full Stack Development Demo (Solidity + Go + React)</p>
      
      {/* 🌈 RainbowKit Provided components */}
      <div style={{ marginTop: '20px' }}>
        <ConnectButton />
      </div>

      <div style={{ marginTop: '50px', border: '1px solid #ccc', padding: '20px', borderRadius: '10px' }}>
        <h3>🚀 status check</h3>
        <p>If you see the connection button above, the frontend environment is successfully set up!</p>
      </div>
    </div>
  );
}

export default App;