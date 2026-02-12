/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'los-dark': '#0a0e27',
        'los-gray': '#1a1f3a',
        'los-blue': '#3b82f6',
        'los-cyan': '#06b6d4',
      },
    },
  },
  plugins: [],
}
