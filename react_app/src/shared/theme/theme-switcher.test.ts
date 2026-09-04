import { beforeEach, describe, expect, it } from 'vitest'
import { useThemeStore } from './theme-store'

describe('Theme Switcher and Tokens', () => {
  beforeEach(() => {
    document.documentElement.removeAttribute('data-theme')
    document.documentElement.removeAttribute('data-palette')
    localStorage.clear()
  })

  it('applies dark theme mode to documentElement attribute and localStorage', () => {
    useThemeStore.getState().setThemeMode('dark')

    expect(document.documentElement.getAttribute('data-theme')).toBe('dark')
    expect(useThemeStore.getState().themeMode).toBe('dark')
    expect(localStorage.getItem('katasticho_theme_mode')).toBe('dark')
  })

  it('applies light theme mode to documentElement attribute and localStorage', () => {
    useThemeStore.getState().setThemeMode('light')

    expect(document.documentElement.getAttribute('data-theme')).toBe('light')
    expect(useThemeStore.getState().themeMode).toBe('light')
    expect(localStorage.getItem('katasticho_theme_mode')).toBe('light')
  })

  it('cycles theme mode sequentially through system, light, dark', () => {
    useThemeStore.getState().setThemeMode('system')

    useThemeStore.getState().cycleThemeMode()
    expect(useThemeStore.getState().themeMode).toBe('light')

    useThemeStore.getState().cycleThemeMode()
    expect(useThemeStore.getState().themeMode).toBe('dark')

    useThemeStore.getState().cycleThemeMode()
    expect(useThemeStore.getState().themeMode).toBe('system')
  })

  it('sets and updates brand palette on documentElement', () => {
    useThemeStore.getState().setBrandPalette('blue')

    expect(document.documentElement.getAttribute('data-palette')).toBe('blue')
    expect(useThemeStore.getState().brandPalette).toBe('blue')
    expect(localStorage.getItem('katasticho_brand_palette')).toBe('blue')
  })
})
