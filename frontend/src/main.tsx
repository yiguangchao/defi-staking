import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './index.css';

import '@rainbow-me/rainbowkit/styles.css';
import { getDefaultConfig, RainbowKitProvider } from '@rainbow-me/rainbowkit';
import { WagmiProvider } from 'wagmi';
import { mainnet, sepolia, foundry } from 'wagmi/chains';
import { QueryClientProvider, QueryClient } from "@tanstack/react-query";

// 2. Configure Chain
const config = getDefaultConfig({
  appName: 'My DeFi App',
  projectId: 'YOUR_PROJECT_ID',
  chains: [foundry, mainnet, sepolia],
  ssr: false, 
});

const queryClient = new QueryClient();

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          <App />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  </React.StrictMode>,
);