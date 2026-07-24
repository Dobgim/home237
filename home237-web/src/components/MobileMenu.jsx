export default function MobileMenu({ navLinks, onClose }) {
  return (
    <div className="md:hidden border-t border-slate-100 bg-white">
      <div className="container-app py-4 space-y-4">
        {navLinks.map((link) => (
          <a
            key={link.href}
            href={link.href}
            className="block text-slate-600 hover:text-ink-900 font-medium"
            onClick={onClose}
          >
            {link.label}
          </a>
        ))}
        <div className="border-t border-slate-100 pt-4 space-y-3">
          <a
            href="https://app.home237.com"
            className="block text-ink-900 font-medium hover:text-blue-900"
            onClick={onClose}
          >
            Explore website
          </a>
          <button
            disabled
            className="w-full btn btn-primary btn-primary-sm btn-disabled"
          >
            Coming soon
          </button>
        </div>
      </div>
    </div>
  );
}
