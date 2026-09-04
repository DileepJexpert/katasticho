import { create } from 'zustand'

export type ThemeMode = 'system' | 'light' | 'dark'
export type BrandPalette = 'teal' | 'blue' | 'amber' | 'indigo' | 'emerald'

export interface BrandPaletteOption {
  id: BrandPalette
  label: string
  color: string
}

export const brandPaletteOptions: readonly BrandPaletteOption[] = [
  { id: 'teal', label: 'Katixo Teal', color: '#0F8576' },
  { id: 'blue', label: 'Clinical Blue', color: '#2563EB' },
  { id: 'amber', label: 'Warm Amber', color: '#B45309' },
  { id: 'indigo', label: 'Royal Indigo', color: '#4F46E5' },
  { id: 'emerald', label: 'Forest Emerald', color: '#059669' },
]

interface ThemeState {
  themeMode: ThemeMode
  brandPalette: BrandPalette
  setThemeMode: (mode: ThemeMode) => void
  cycleThemeMode: () => void
  setBrandPalette: (palette: BrandPalette) => void
}

const THEME_KEY = 'katasticho_theme_mode'
const PALETTE_KEY = 'katasticho_brand_palette'

function getInitialThemeMode(): ThemeMode {
  try {
    const saved = localStorage.getItem(THEME_KEY)
    if (saved === 'light' || saved === 'dark' || saved === 'system') return saved
  } catch {
    // fallback
  }
  return 'system'
}

function getInitialBrandPalette(): BrandPalette {
  try {
    const saved = localStorage.getItem(PALETTE_KEY)
    if (saved === 'teal' || saved === 'blue' || saved === 'amber' || saved === 'indigo' || saved === 'emerald') {
      return saved
    }
  } catch {
    // fallback
  }
  return 'teal'
}

function applyThemeToDOM(mode: ThemeMode, palette: BrandPalette) {
  if (typeof document === 'undefined') return
  const root = document.documentElement
  root.setAttribute('data-palette', palette)

  let resolved = mode
  if (mode === 'system') {
    resolved =
      typeof window !== 'undefined' &&
      typeof window.matchMedia === 'function' &&
      window.matchMedia('(prefers-color-scheme: dark)').matches
        ? 'dark'
        : 'light'
  }
  root.setAttribute('data-theme', resolved)
}

export const useThemeStore = create<ThemeState>((set, get) => {
  const initialMode = getInitialThemeMode()
  const initialPalette = getInitialBrandPalette()

  // Apply on startup if in browser
  if (typeof window !== 'undefined') {
    applyThemeToDOM(initialMode, initialPalette)

    // Listen to OS theme changes if on system mode
    if (typeof window.matchMedia === 'function') {
      const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)')
      mediaQuery.addEventListener?.('change', () => {
        if (get().themeMode === 'system') {
          applyThemeToDOM('system', get().brandPalette)
        }
      })
    }
  }

  return {
    themeMode: initialMode,
    brandPalette: initialPalette,
    setThemeMode: (mode) => {
      try {
        localStorage.setItem(THEME_KEY, mode)
      } catch {
        // Ignore localStorage access restrictions in sandboxed iframes
      }
      applyThemeToDOM(mode, get().brandPalette)
      set({ themeMode: mode })
    },
    cycleThemeMode: () => {
      const current = get().themeMode
      const next: ThemeMode = current === 'system' ? 'light' : current === 'light' ? 'dark' : 'system'
      get().setThemeMode(next)
    },
    setBrandPalette: (palette) => {
      try {
        localStorage.setItem(PALETTE_KEY, palette)
      } catch {
        // Ignore localStorage access restrictions in sandboxed iframes
      }
      applyThemeToDOM(get().themeMode, palette)
      set({ brandPalette: palette })
    },
  }
})
