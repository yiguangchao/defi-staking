import { ConnectButton } from '@rainbow-me/rainbowkit';
import { EventsTable } from './components/EventsTable';
import { ActionPanel } from './components/ActionPanel';
import { VaultInfo } from './components/VaultInfo';
import { TVLChart } from './components/TVLChart';
import { Toaster } from 'react-hot-toast'; 

function App() {
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '50px',
      fontFamily: 'sans-serif',
      maxWidth: '800px',
      margin: '0 auto',
      background: '#f8fafc',
      minHeight: '100vh'
    }}>
      <Toaster position="top-center" reverseOrder={false} />
      <h1 style={{ marginBottom: '10px' }}>🏦 My DeFi Vault</h1>
      <p style={{ color: '#64748b', marginBottom: '30px' }}>Web3 full-stack demo (Solidity + Go + React)</p>
      
      {/* 🌈 Wallet connection */}
      <div style={{ marginBottom: '30px' }}>
        <ConnectButton />
      </div>

      {/* Two core component containers */}
      <div style={{ width: '100%', maxWidth: '600px' }}>
        {/* 1. Top board */}
        <VaultInfo />

        {/* 2. Action Panel */}
        <ActionPanel />
        
        {/* 3. data table */}
        <EventsTable />

        {/* 4. TVL Chart */}
        <TVLChart />
      </div>

    </div>
  );
}

export default App;