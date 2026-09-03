import {
  Building2,
  LogOut,
  Menu,
  Search,
} from 'lucide-react'
import { useState } from 'react'
import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import { getVisibleNavigation } from '@/app/navigation'
import { Button } from '@/design-system/button'
import { CommandPalette } from '@/design-system/command-palette'
import { useSessionStore } from '@/shared/session/session-store'

export function AppShell() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false)
  const navigate = useNavigate()
  const user = useSessionStore((state) => state.user)
  const logout = useSessionStore((state) => state.logout)
  const navigation = getVisibleNavigation({
    role: user?.role,
    industry: user?.industryCode ?? user?.industry,
    country: null,
  })

  async function handleLogout() {
    await logout()
  }

  return (
    <div className="app-shell">
      <aside className={menuOpen ? 'sidebar sidebar--open' : 'sidebar'} aria-label="Main navigation">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">K</span>
          <span>Katasticho</span>
        </div>

        <nav className="sidebar-nav">
          {navigation.map((item) => {
            const Icon = item.icon
            return (
              <NavLink className="sidebar-link" key={item.id} onClick={() => setMenuOpen(false)} to={item.to}>
                <Icon size={18} aria-hidden="true" />
                {item.label}
              </NavLink>
            )
          })}
        </nav>

        <div className="sidebar-footer">
          <div className="user-summary">
            <span className="user-avatar" aria-hidden="true">{user?.fullName.slice(0, 1).toUpperCase()}</span>
            <span>
              <strong>{user?.fullName}</strong>
              <small>{user?.role.replaceAll('_', ' ')}</small>
            </span>
          </div>
          <Button className="logout-button" onClick={handleLogout} variant="ghost">
            <LogOut size={16} aria-hidden="true" />
            Sign out
          </Button>
        </div>
      </aside>

      <div className="app-frame">
        <header className="topbar">
          <Button aria-label="Open navigation" className="menu-button" onClick={() => setMenuOpen((open) => !open)} variant="ghost">
            <Menu size={20} aria-hidden="true" />
          </Button>
          <button aria-haspopup="dialog" className="global-search" onClick={() => setCommandPaletteOpen(true)} type="button">
            <span><Search size={18} aria-hidden="true" /><span>Search or jump to...</span></span>
            <kbd>Ctrl K</kbd>
          </button>
          <div className="topbar-actions">
            <span className="org-context"><Building2 size={16} aria-hidden="true" /> {user?.orgName}</span>
          </div>
        </header>
        <main className="app-content"><Outlet /></main>
      </div>
      <CommandPalette
        isOpen={commandPaletteOpen}
        navigation={navigation}
        onNavigate={(to) => {
          setMenuOpen(false)
          navigate(to)
        }}
        onOpenChange={setCommandPaletteOpen}
        onSignOut={() => {
          void handleLogout()
        }}
      />
    </div>
  )
}
