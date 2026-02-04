import React from 'react'

export default function TestApp() {
  return (
    <div style={{ 
      padding: '40px', 
      backgroundColor: '#0a0a0f', 
      color: 'white',
      minHeight: '100vh',
      fontFamily: 'Arial'
    }}>
      <h1 style={{ color: '#06b6d4', fontSize: '32px' }}>✅ React is Working!</h1>
      <p>If you see this, React and Vite are running correctly.</p>
      
      <div style={{ marginTop: '20px', padding: '20px', backgroundColor: '#1a1a24', borderRadius: '8px' }}>
        <h2>Debug Info:</h2>
        <ul>
          <li>React: {React.version}</li>
          <li>Environment: production</li>
          <li>Time: {new Date().toLocaleString()}</li>
        </ul>
      </div>

      <button 
        onClick={() => alert('Button works!')}
        style={{
          marginTop: '20px',
          padding: '10px 20px',
          backgroundColor: '#2563eb',
          color: 'white',
          border: 'none',
          borderRadius: '8px',
          cursor: 'pointer'
        }}
      >
        Test Click
      </button>
    </div>
  );
}
