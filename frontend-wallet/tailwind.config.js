/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'los-dark': '#0a0a0f',
        'los-gray': '#1a1a24',
        'los-blue': '#2563eb',
        'los-cyan': '#06b6d4',
        'los-orange': '#f97316',
      },
    },
  },
  plugins: [],
}
