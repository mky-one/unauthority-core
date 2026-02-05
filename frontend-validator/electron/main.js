import { app, BrowserWindow, shell } from 'electron';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

let mainWindow;

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 1000,
    minHeight: 700,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
    backgroundColor: '#0a0e27',
    icon: path.join(__dirname, '../public/icon.png'),
    titleBarStyle: 'hiddenInset',
  });

  // Configure Tor SOCKS proxy for .onion URLs (same as Bitcoin Core)
  // Tries common Tor ports: 9150 (Tor Browser), 9050 (Tor daemon)
  mainWindow.webContents.session.setProxy({
    proxyRules: 'socks5://127.0.0.1:9150',
    proxyBypassRules: 'localhost,127.0.0.1'
  }).catch(() => {
    // Fallback to Tor daemon port if Tor Browser proxy fails
    mainWindow.webContents.session.setProxy({
      proxyRules: 'socks5://127.0.0.1:9050',
      proxyBypassRules: 'localhost,127.0.0.1'
    }).catch((err) => {
      console.warn('Tor proxy not available:', err.message);
      console.warn('Please ensure Tor Browser is running or install Tor daemon');
    });
  });

  // Load app
  if (process.env.NODE_ENV === 'development' || !app.isPackaged) {
    mainWindow.loadURL('http://localhost:5174');
    mainWindow.webContents.openDevTools();
  } else {
    mainWindow.loadFile(path.join(__dirname, '../dist/index.html'));
  }

  // Open external links in browser
  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('http')) {
      shell.openExternal(url);
      return { action: 'deny' };
    }
    return { action: 'allow' };
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
  });
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('activate', () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
