import { useQuery } from '@tanstack/react-query';
import {
  AreaChart,
  Area,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer
} from 'recharts';

interface HistoryPoint {
  id: number;
  time: string;
  tvl: number;
  change: number;
}

export const TVLChart = () => {
  const { data, isLoading } = useQuery({
    queryKey: ['history'],
    queryFn: async () => {
      const res = await fetch('http://localhost:8080/api/history');
      return res.json();
    },
    refetchInterval: 5000, // Refresh every 5 seconds
  });

  const chartData: HistoryPoint[] = data?.data || [];

  if (isLoading) return <div style={{textAlign: 'center', padding: '20px'}}>📊 Chart loading in progress...</div>;

  return (
    <div style={{ 
      border: '1px solid #e2e8f0', 
      borderRadius: '12px', 
      padding: '20px', 
      marginBottom: '20px',
      background: 'white',
      height: '300px'
    }}>
      <h3 style={{marginTop: 0, marginBottom: '20px', color: '#475569'}}>📊 Fund pool trend (TVL History)</h3>
      
      <div style={{ width: '100%', height: '85%' }}>
        <ResponsiveContainer width="100%" height="100%">
          <AreaChart data={chartData}>
            <defs>
              {/* Define beautiful gradient colors */}
              <linearGradient id="colorTvl" x1="0" y1="0" x2="0" y2="1">
                <stop offset="5%" stopColor="#8884d8" stopOpacity={0.8}/>
                <stop offset="95%" stopColor="#8884d8" stopOpacity={0}/>
              </linearGradient>
            </defs>
            <CartesianGrid strokeDasharray="3 3" vertical={false} />
            <XAxis 
              dataKey="time" 
              tick={{fontSize: 12}} 
              minTickGap={30}
            />
            <YAxis 
              tick={{fontSize: 12}} 
              width={40}
            />
            <Tooltip 
              contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
            />
            <Area 
              type="monotone"
              dataKey="tvl" 
              stroke="#8884d8" 
              fillOpacity={1} 
              fill="url(#colorTvl)" 
              animationDuration={500}
            />
          </AreaChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
};