import {
  Bell,
  Building2,
  Check,
  ChevronRight,
  LogOut,
  Menu,
  Moon,
  Palette,
  Search,
  Sparkles,
  Sun,
  User,
  X,
} from 'lucide-react'
import { useState, useRef, useEffect } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import {
  appRoutes,
  getVisibleNavStructure,
  getVisibleNavigation,
  type NavGroup,
} from '@/app/navigation'
import { Button } from '@/design-system/button'
import { CommandPalette } from '@/design-system/command-palette'
import { QuickCreateMenu } from '@/app/shell/quick-create-menu'
import { OrgSwitcherModal } from '@/features/auth/org-switcher-modal'
import { useSessionStore } from '@/shared/session/session-store'
import {
  brandPaletteOptions,
  useThemeStore,
} from '@/shared/theme/theme-store'

export function AppShell() {
  const [menuOpen, setMenuOpen] = useState(false)
  const [commandPaletteOpen, setCommandPaletteOpen] = useState(false)
  const [profileDropdownOpen, setProfileDropdownOpen] = useState(false)
  const [paletteDropdownOpen, setPaletteDropdownOpen] = useState(false)
  const [orgSwitcherOpen, setOrgSwitcherOpen] = useState(false)
  const [activeFlyoutGroup, setActiveFlyoutGroup] = useState<NavGroup | null>(null)
  const [flyoutPosition, setFlyoutPosition] = useState<{ top: number; left: number }>({ top: 0, left: 0 })
  const [expandedMobileGroups, setExpandedMobileGroups] = useState<Record<string, boolean>>({})

  const hoverTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null)
  const profileMenuRef = useRef<HTMLDivElement>(null)
  const paletteMenuRef = useRef<HTMLDivElement>(null)
  const sidebarNavRef = useRef<HTMLElement>(null)

  const navigate = useNavigate()
  const location = useLocation()
  const user = useSessionStore((state) => state.user)
  const logout = useSessionStore((state) => state.logout)

  const themeMode = useThemeStore((state) => state.themeMode)
  const cycleThemeMode = useThemeStore((state) => state.cycleThemeMode)
  const brandPalette = useThemeStore((state) => state.brandPalette)
  const setBrandPalette = useThemeStore((state) => state.setBrandPalette)

  const navContext = {
    role: user?.role,
    industry: user?.industryCode ?? user?.industry,
    // The authenticated web-session contract does not include an organisation
    // country. Keep country-gated navigation hidden rather than assume India.
    country: undefined,
  }

  const { topItems, groups, bottomItems } = getVisibleNavStructure(navContext)
  const flatNavigation = getVisibleNavigation(navContext)

  // Close menus on outside click
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (profileMenuRef.current && !profileMenuRef.current.contains(e.target as Node)) {
        setProfileDropdownOpen(false)
      }
      if (paletteMenuRef.current && !paletteMenuRef.current.contains(e.target as Node)) {
        setPaletteDropdownOpen(false)
      }
    }
    document.addEventListener('mousedown', handleClickOutside)
    return () => document.removeEventListener('mousedown', handleClickOutside)
  }, [])

  // Close flyout on route change
  useEffect(() => {
    setActiveFlyoutGroup(null)
  }, [location.pathname])

  async function handleLogout() {
    setProfileDropdownOpen(false)
    await logout()
    navigate('/login')
  }

  function handleGroupMouseEnter(group: NavGroup, event: React.MouseEvent<HTMLElement>) {
    if (window.innerWidth <= 760) return
    if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current)
    const rect = event.currentTarget.getBoundingClientRect()
    setFlyoutPosition({
      top: Math.max(12, Math.min(rect.top - 8, window.innerHeight - 440)),
      left: rect.right + 6,
    })
    setActiveFlyoutGroup(group)
  }

  function handleGroupMouseLeave() {
    if (window.innerWidth <= 760) return
    hoverTimerRef.current = setTimeout(() => {
      setActiveFlyoutGroup(null)
    }, 180)
  }

  function handleFlyoutMouseEnter() {
    if (hoverTimerRef.current) clearTimeout(hoverTimerRef.current)
  }

  function handleFlyoutMouseLeave() {
    hoverTimerRef.current = setTimeout(() => {
      setActiveFlyoutGroup(null)
    }, 180)
  }

  function toggleMobileGroup(groupId: string) {
    setExpandedMobileGroups((prev) => ({
      ...prev,
      [groupId]: !prev[groupId],
    }))
  }

  const isGroupActive = (group: NavGroup) =>
    group.items.some((item) =>
      item.to === '/' ? location.pathname === '/' : location.pathname.startsWith(item.to)
    )

  return (
    <div className="app-shell">
      {/* ── Sidebar ── */}
      <aside className={menuOpen ? 'sidebar sidebar--open' : 'sidebar'} aria-label="Main navigation">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true">K</span>
          <span className="brand-title">Katasticho</span>
          <button
            aria-label="Close menu"
            className="sidebar-close-btn"
            onClick={() => setMenuOpen(false)}
            type="button"
          >
            <X size={18} aria-hidden="true" />
          </button>
        </div>

        <div className="sidebar-quick-create">
          <QuickCreateMenu expanded />
        </div>

        <nav className="sidebar-nav" ref={sidebarNavRef}>
          {/* Top-Level Items (Overview, AI, POS) */}
          <div className="nav-section">
            {topItems.map((item) => {
              const Icon = item.icon
              return (
                <NavLink
                  className="sidebar-link"
                  key={item.id}
                  onClick={() => setMenuOpen(false)}
                  to={item.to}
                >
                  <Icon size={17} aria-hidden="true" />
                  <span className="sidebar-link__label">{item.label}</span>
                </NavLink>
              )
            })}
          </div>

          <div className="nav-divider" />

          {/* Group Items with Hover Submenus */}
          <div className="nav-section">
            <span className="nav-section-title">Operations</span>
            {groups.map((group) => {
              const Icon = group.icon
              const active = isGroupActive(group)
              const mobileExpanded = !!expandedMobileGroups[group.id]

              return (
                <div
                  className="nav-group-wrapper"
                  key={group.id}
                  onMouseEnter={(e) => handleGroupMouseEnter(group, e)}
                  onMouseLeave={handleGroupMouseLeave}
                >
                  <button
                    aria-expanded={mobileExpanded}
                    className={active ? 'nav-group-btn nav-group-btn--active' : 'nav-group-btn'}
                    onClick={() => {
                      if (window.innerWidth <= 760) {
                        toggleMobileGroup(group.id)
                      } else {
                        const firstItem = group.items[0]
                        if (firstItem) {
                          navigate(firstItem.to)
                        }
                      }
                    }}
                    type="button"
                  >
                    <Icon size={17} aria-hidden="true" />
                    <span className="nav-group-btn__label">{group.label}</span>
                    <ChevronRight
                      className={mobileExpanded ? 'nav-group-chevron nav-group-chevron--rotated' : 'nav-group-chevron'}
                      size={14}
                      aria-hidden="true"
                    />
                  </button>

                  {/* Mobile Accordion Submenu */}
                  {mobileExpanded && (
                    <div className="mobile-submenu">
                      {group.items.map((subItem) => {
                        const SubIcon = subItem.icon
                        return (
                          <NavLink
                            className="mobile-sublink"
                            key={subItem.id}
                            onClick={() => setMenuOpen(false)}
                            to={subItem.to}
                          >
                            <SubIcon size={15} aria-hidden="true" />
                            <span>{subItem.label}</span>
                          </NavLink>
                        )
                      })}
                    </div>
                  )}
                </div>
              )
            })}
          </div>

          <div className="nav-divider" />

          {/* Bottom Items (Contacts, Settings) */}
          <div className="nav-section">
            {bottomItems.map((item) => {
              const Icon = item.icon
              return (
                <NavLink
                  className="sidebar-link"
                  key={item.id}
                  onClick={() => setMenuOpen(false)}
                  to={item.to}
                >
                  <Icon size={17} aria-hidden="true" />
                  <span className="sidebar-link__label">{item.label}</span>
                </NavLink>
              )
            })}
          </div>
        </nav>

        {/* Floating Hover Submenu Flyout (Desktop) */}
        {activeFlyoutGroup && (
          <div
            className="nav-group-flyout"
            onMouseEnter={handleFlyoutMouseEnter}
            onMouseLeave={handleFlyoutMouseLeave}
            style={{ top: `${flyoutPosition.top}px`, left: `${flyoutPosition.left}px` }}
          >
            <div className="flyout-header">
              <span className="flyout-title">{activeFlyoutGroup.label}</span>
              <span className="flyout-count">{activeFlyoutGroup.items.length} modules</span>
            </div>
            <div className="flyout-items">
              {activeFlyoutGroup.items.map((subItem) => {
                const SubIcon = subItem.icon
                const isActive =
                  subItem.to === '/'
                    ? location.pathname === '/'
                    : location.pathname === subItem.to || location.pathname.startsWith(subItem.to + '/')

                return (
                  <NavLink
                    className={isActive ? 'flyout-item flyout-item--active' : 'flyout-item'}
                    key={subItem.id}
                    onClick={() => {
                      setActiveFlyoutGroup(null)
                      setMenuOpen(false)
                    }}
                    to={subItem.to}
                  >
                    <span className="flyout-item__icon">
                      <SubIcon size={15} aria-hidden="true" />
                    </span>
                    <div className="flyout-item__content">
                      <span className="flyout-item__label">{subItem.label}</span>
                      <small className="flyout-item__desc">{subItem.description}</small>
                    </div>
                  </NavLink>
                )
              })}
            </div>
          </div>
        )}

        {/* Sidebar Footer */}
        <div className="sidebar-footer">
          <div className="sidebar-footer__user">
            <span className="user-avatar" aria-hidden="true">
              {user?.fullName ? user.fullName.charAt(0).toUpperCase() : 'U'}
            </span>
            <div className="user-details">
              <strong>{user?.fullName ?? 'Operator'}</strong>
              <small>{user?.role ? user.role.replace('_', ' ') : 'Administrator'}</small>
            </div>
          </div>

          <div className="sidebar-footer__actions">
            <button
              aria-label="Theme mode"
              className="footer-action-btn"
              onClick={cycleThemeMode}
              title={`Theme: ${themeMode} (click to toggle)`}
              type="button"
            >
              {themeMode === 'dark' ? <Moon size={15} /> : <Sun size={15} />}
            </button>
            <button
              aria-label="Sign out"
              className="footer-action-btn footer-action-btn--danger"
              onClick={handleLogout}
              title="Sign out"
              type="button"
            >
              <LogOut size={15} />
            </button>
          </div>
        </div>
      </aside>

      {/* ── Main Application Frame ── */}
      <div className="app-frame">
        {/* TopBar */}
        <header className="topbar">
          <Button
            aria-label="Open navigation"
            className="menu-button"
            onClick={() => setMenuOpen((open) => !open)}
            variant="ghost"
          >
            <Menu size={20} aria-hidden="true" />
          </Button>

          {/* Quick Create in Topbar */}
          <div className="topbar-quick-create">
            <QuickCreateMenu expanded={false} />
          </div>

          {/* Global Search Bar (Ctrl+K) */}
          <button
            aria-haspopup="dialog"
            className="global-search"
            onClick={() => setCommandPaletteOpen(true)}
            type="button"
          >
            <span>
              <Search size={16} aria-hidden="true" />
              <span>Search or jump to...</span>
            </span>
            <kbd>Ctrl K</kbd>
          </button>

          {/* Topbar Actions */}
          <div className="topbar-actions">
            {/* Ask AI Copilot Button */}
            <button
              className="topbar-ai-btn"
              onClick={() => navigate('/ai')}
              title="AI Command Center & Copilot"
              type="button"
            >
              <Sparkles size={15} aria-hidden="true" />
              <span>Ask AI</span>
            </button>

            {/* Notifications Button */}
            <button
              aria-label="Notifications"
              className="topbar-icon-btn"
              onClick={() => navigate('/notifications')}
              title="Notifications"
              type="button"
            >
              <Bell size={17} aria-hidden="true" />
            </button>

            {/* Brand Palette Switcher Dropdown */}
            <div className="palette-switcher-container" ref={paletteMenuRef}>
              <button
                aria-expanded={paletteDropdownOpen}
                aria-label="Brand Theme Palette"
                className="topbar-icon-btn"
                onClick={() => setPaletteDropdownOpen((prev) => !prev)}
                title="Brand Theme Palette"
                type="button"
              >
                <Palette size={17} aria-hidden="true" />
              </button>

              {paletteDropdownOpen && (
                <div className="palette-dropdown" role="menu">
                  <div className="palette-dropdown__header">
                    <span>Brand Accent Color</span>
                  </div>
                  {brandPaletteOptions.map((opt) => (
                    <button
                      className={brandPalette === opt.id ? 'palette-option palette-option--active' : 'palette-option'}
                      key={opt.id}
                      onClick={() => {
                        setBrandPalette(opt.id)
                        setPaletteDropdownOpen(false)
                      }}
                      type="button"
                    >
                      <span className="palette-dot" style={{ backgroundColor: opt.color }} />
                      <span className="palette-label">{opt.label}</span>
                      {brandPalette === opt.id && <Check size={14} className="palette-check" />}
                    </button>
                  ))}
                </div>
              )}
            </div>

            {/* Theme Mode Switcher Button */}
            <button
              aria-label="Toggle light/dark theme"
              className="topbar-icon-btn"
              onClick={cycleThemeMode}
              title={`Theme: ${themeMode} (click to toggle)`}
              type="button"
            >
              {themeMode === 'dark' ? <Moon size={17} /> : <Sun size={17} />}
            </button>

            <div className="topbar-divider" />

            {/* Organization & User Profile Menu */}
            <div className="profile-menu-container" ref={profileMenuRef}>
              <button
                aria-expanded={profileDropdownOpen}
                className="user-profile-btn"
                onClick={() => setProfileDropdownOpen((prev) => !prev)}
                type="button"
              >
                <span className="user-avatar" aria-hidden="true">
                  {user?.fullName ? user.fullName.charAt(0).toUpperCase() : 'U'}
                </span>
                <span className="user-profile-name">{user?.fullName ?? 'Account'}</span>
              </button>

              {profileDropdownOpen && (
                <div className="profile-dropdown" role="menu">
                  <div className="profile-dropdown__header">
                    <strong>{user?.fullName ?? 'Operator'}</strong>
                    <small>{user?.role ? user.role.replace('_', ' ') : 'Administrator'}</small>
                    <span className="profile-org">
                      <Building2 size={13} aria-hidden="true" />
                      <span>{user?.orgName ?? 'Katasticho ERP'}</span>
                    </span>
                  </div>

                  <div className="profile-dropdown__menu">
                    <button
                      className="profile-menu-item"
                      onClick={() => {
                        setProfileDropdownOpen(false)
                        setOrgSwitcherOpen(true)
                      }}
                      type="button"
                    >
                      <Building2 size={15} aria-hidden="true" />
                      <span>Switch Organisation</span>
                    </button>

                    <button
                      className="profile-menu-item"
                      onClick={() => {
                        setProfileDropdownOpen(false)
                        navigate(appRoutes.users)
                      }}
                      type="button"
                    >
                      <User size={15} aria-hidden="true" />
                      <span>Team & User Roles</span>
                    </button>

                    <button
                      className="profile-menu-item profile-menu-item--danger"
                      onClick={handleLogout}
                      type="button"
                    >
                      <LogOut size={15} aria-hidden="true" />
                      <span>Sign Out</span>
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
        </header>

        {/* Application View Outlet */}
        <main className="app-content">
          <Outlet />
        </main>
      </div>

      {/* Global Command Palette (Ctrl+K) */}
      <CommandPalette
        isOpen={commandPaletteOpen}
        navigation={flatNavigation}
        onNavigate={(to) => {
          setMenuOpen(false)
          navigate(to)
        }}
        onOpenChange={setCommandPaletteOpen}
        onSignOut={() => {
          void handleLogout()
        }}
      />

      {/* Organisation Switcher Modal */}
      <OrgSwitcherModal
        isOpen={orgSwitcherOpen}
        onClose={() => setOrgSwitcherOpen(false)}
      />
    </div>
  )
}
