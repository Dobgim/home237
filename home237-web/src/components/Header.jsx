import { useState } from 'react';
import { Menu, X } from 'lucide-react';
import MobileMenu from './MobileMenu';

const navLinks = [
  { label: 'Why us', href: '#features' },
  { label: 'Process', href: '#how' },
  { label: 'Stories', href: '#testimonials' },
  { label: 'Help', href: '#faq' },
  { label: 'Contact', href: '#contact' },
];

export default function Header() {
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);

  return (
    <>
      {/* Topbar */}
      <div className="bg-ink-900 text-white py-2.5 text-sm">
        <div className="container-app flex items-center justify-between">
          <span className="truncate">Browse verified homes across 6+ Cameroon cities.</span>
          <a href="#top" className="hidden sm:inline hover:text-green-400 transition whitespace-nowrap">
            Explore now →
          </a>
        </div>
      </div>

      {/* Navigation */}
      <header className="sticky top-0 z-40 bg-white/90 backdrop-blur border-b border-slate-100">
        <nav className="container-app flex items-center justify-between h-18">
          {/* Logo */}
          <a href="#top" className="flex items-center gap-2">
            <img src="/favicon.png" alt="Home237 logo" width="40" height="40" className="w-10 h-10 object-contain" />
            <span className="font-black text-lg text-ink-900">
              Home<span className="text-blue-900">237</span>
            </span>
          </a>

          {/* Desktop Nav Links */}
          <div className="hidden md:flex items-center gap-8">
            {navLinks.map((link) => (
              <a
                key={link.href}
                href={link.href}
                className="text-slate-600 hover:text-ink-900 transition font-medium"
              >
                {link.label}
              </a>
            ))}
          </div>

          {/* Desktop Actions */}
          <div className="hidden md:flex items-center gap-4">
            <a
              href="https://home237.com"
              className="text-ink-900 hover:text-blue-900 transition font-medium"
            >
              Explore website
            </a>
            <button
              disabled
              className="btn btn-primary btn-primary-sm btn-disabled"
              aria-label="Download coming soon"
            >
              Coming soon
            </button>
          </div>

          {/* Mobile Menu Toggle */}
          <button
            onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
            className="md:hidden p-2 text-ink-900"
            aria-label="Toggle menu"
            aria-expanded={mobileMenuOpen}
          >
            {mobileMenuOpen ? <X size={24} /> : <Menu size={24} />}
          </button>
        </nav>

        {mobileMenuOpen && (
          <MobileMenu navLinks={navLinks} onClose={() => setMobileMenuOpen(false)} />
        )}
      </header>
    </>
  );
}
