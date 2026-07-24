/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,jsx,ts,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Primary colors
        blue: {
          50: '#F5F6FF',    // mist
          100: '#EEF0FF',   // soft
          400: '#3D52D4',   // light
          500: '#1A2FB8',   // mid
          800: '#0A1F9E',   // hover mid
          900: '#001A9E',   // primary
          950: '#000F5C',   // deep
        },
        green: {
          50: '#E6F7EF',    // soft
          400: '#34D399',   // bright
          600: '#0F9F6E',   // accent
        },
        ink: {
          800: '#0B0D17',   // primary text
          900: '#07070C',   // black
        },
        slate: {
          50: '#F7F8FB',    // grey
          100: '#E8EAF0',   // line
          200: '#D8DCE6',   // line-2
          400: '#8B93A7',   // muted-2
          500: '#5B6475',   // muted
          600: '#4A5264',   // body
          800: '#1C2233',   // footer border
        },
      },
      fontFamily: {
        sans: ['"Plus Jakarta Sans"', 'system-ui', '-apple-system', 'sans-serif'],
      },
      fontSize: {
        xs: '13px',
        sm: '14px',
        base: '16px',
      },
      spacing: {
        safe: '28px', // container padding
        18: '72px',   // header height (h-18)
      },
      opacity: {
        65: '0.65',
      },
      borderRadius: {
        xs: '8px',
        sm: '12px',
        md: '16px',
        lg: '24px',
      },
      boxShadow: {
        xs: '0 1px 2px rgba(11, 13, 23, 0.04)',
        sm: '0 4px 16px rgba(11, 13, 23, 0.05)',
        md: '0 12px 40px rgba(11, 13, 23, 0.08)',
        lg: '0 28px 64px rgba(11, 13, 23, 0.12)',
        'blue-lg': '0 16px 40px rgba(0, 26, 158, 0.28)',
      },
      maxWidth: {
        app: '1160px',
      },
      animation: {
        reveal: 'reveal 0.8s cubic-bezier(0.22, 1, 0.36, 1) forwards',
      },
      keyframes: {
        reveal: {
          '0%': { opacity: '0', transform: 'translateY(28px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
      },
    },
  },
  plugins: [],
}
