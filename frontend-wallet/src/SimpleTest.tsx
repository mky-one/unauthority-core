import React from 'react';

export default function SimpleTest() {
  const [count, setCount] = React.useState(0);

  return (
    <div style={{ 
      minHeight: '100vh',
      background: 'linear-gradient(to bottom right, #0a0a0f, #1a1a24)',
      color: 'white',
      padding: '40px',
      fontFamily: 'system-ui, -apple-system, sans-serif'
    }}>
      <div style={{
        maxWidth: '600px',
        margin: '0 auto',
        backgroundColor: '#1a1a24',
        padding: '40px',
        borderRadius: '16px',
        border: '1px solid #333'
      }}>
        <h1 style={{ 
          fontSize: '36px', 
          marginBottom: '20px',
          background: 'linear-gradient(to right, #2563eb, #06b6d4)',
          WebkitBackgroundClip: 'text',
          WebkitTextFillColor: 'transparent'
        }}>
          ✅ Unauthority Wallet Test
        </h1>
        
        <p style={{ color: '#9ca3af', marginBottom: '30px' }}>
          If you see this, React is working correctly!
        </p>

        <div style={{
          padding: '20px',
          backgroundColor: '#0a0a0f',
          borderRadius: '8px',
          marginBottom: '20px'
        }}>
          <h2 style={{ fontSize: '24px', marginBottom: '10px' }}>Counter Test</h2>
          <p style={{ fontSize: '48px', fontWeight: 'bold', color: '#06b6d4' }}>{count}</p>
          <button
            onClick={() => setCount(count + 1)}
            style={{
              padding: '12px 24px',
              backgroundColor: '#2563eb',
              color: 'white',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              cursor: 'pointer',
              fontWeight: '600'
            }}
          >
            Click Me!
          </button>
        </div>

        <div style={{
          padding: '16px',
          backgroundColor: '#166534',
          borderRadius: '8px',
          border: '1px solid #16a34a'
        }}>
          <h3 style={{ fontSize: '18px', marginBottom: '10px' }}>✅ Working Features:</h3>
          <ul style={{ margin: 0, paddingLeft: '20px', color: '#86efac' }}>
            <li>React rendering</li>
            <li>State management (useState)</li>
            <li>Event handlers (onClick)</li>
            <li>Inline styles</li>
          </ul>
        </div>

        <p style={{ 
          marginTop: '30px', 
          fontSize: '14px', 
          color: '#6b7280',
          textAlign: 'center'
        }}>
          Return to full wallet: Edit src/main.tsx
        </p>
      </div>
    </div>
  );
}
