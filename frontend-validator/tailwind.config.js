/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'uat-dark': '#0a0e27',
        'uat-gray': '#1a1f3a',
        'uat-blue': '#3b82f6',
        'uat-cyan': '#06b6d4',
      },
    },
  },
  plugins: [],
}
