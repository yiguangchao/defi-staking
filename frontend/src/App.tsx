import { ConnectButton } from '@rainbow-me/rainbowkit';
import { EventsTable } from './components/EventsTable'; // 👈 引入组件

function App() {
  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      padding: '50px',
      fontFamily: 'sans-serif',
      maxWidth: '800px',
      margin: '0 auto' // 居中
    }}>
      <h1>🏦 我的 DeFi 金库</h1>
      <p style={{ color: '#666' }}>Web3 全栈开发演示 (Solidity + Go + React)</p>
      
      {/* 🌈 钱包连接 */}
      <div style={{ margin: '20px 0' }}>
        <ConnectButton />
      </div>

      {/* 📊 数据表格组件 */}
      <EventsTable /> 

    </div>
  );
}

export default App;