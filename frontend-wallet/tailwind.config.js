/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        'uat-dark': '#0a0a0f',
        'uat-gray': '#1a1a24',
        'uat-blue': '#2563eb',
        'uat-cyan': '#06b6d4',
        'uat-orange': '#f97316',
      },
    },
  },
  plugins: [],
}
