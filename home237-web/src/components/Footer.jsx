import { Facebook, Twitter, Instagram, Linkedin, Send } from 'lucide-react';
import { useState } from 'react';

const columns = [
  { title: 'Product', links: ['Why us', 'Process', 'Stories', 'Get the app'] },
  { title: 'Cities', links: ['Douala', 'Yaoundé', 'Buea', 'Bamenda', 'Bafoussam', 'Limbe'] },
  { title: 'Company', links: ['About', 'Help', 'Careers', 'Contact'] },
  { title: 'Legal', links: ['Terms', 'Privacy', 'Cookies'] },
];

const socials = [
  { icon: Facebook, label: 'Facebook' },
  { icon: Twitter, label: 'X' },
  { icon: Instagram, label: 'Instagram' },
  { icon: Linkedin, label: 'LinkedIn' },
];

export default function Footer() {
  const [email, setEmail] = useState('');
  const [message, setMessage] = useState('');

  const handleSubmit = (e) => {
    e.preventDefault();
    if (email) {
      setMessage('Thanks for subscribing!');
      setEmail('');
      setTimeout(() => setMessage(''), 3000);
    }
  };

  const currentYear = new Date().getFullYear();

  return (
    <footer className="bg-ink-900 text-white" id="contact">
      <div className="border-b border-slate-800 py-16">
        <div className="container-app">
          <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-10">
            {/* Brand */}
            <div className="col-span-2">
              <a href="#top" className="flex items-center gap-2 mb-4">
                <img src="/favicon.png" alt="Home237 logo" width="40" height="40" className="w-10 h-10 object-contain" />
                <span className="font-black text-lg">
                  Home<span className="text-blue-400">237</span>
                </span>
              </a>
              <p className="text-slate-400 text-sm mb-6 max-w-xs">
                The straightforward way to find and list rental homes in Cameroon — checked
                listings, clear visits, Mobile Money ready.
              </p>
              <div className="flex gap-4">
                {socials.map(({ icon: Icon, label }) => (
                  <a key={label} href="#" className="text-slate-400 hover:text-white transition" aria-label={label}>
                    <Icon size={18} />
                  </a>
                ))}
              </div>
            </div>

            {/* Link Columns */}
            {columns.map((col) => (
              <nav key={col.title}>
                <h4 className="font-bold mb-4">{col.title}</h4>
                <ul className="space-y-3">
                  {col.links.map((link) => (
                    <li key={link}>
                      <a href="#" className="text-slate-400 hover:text-white transition text-sm">
                        {link}
                      </a>
                    </li>
                  ))}
                </ul>
              </nav>
            ))}
          </div>

          {/* Newsletter */}
          <div className="mt-12 pt-10 border-t border-slate-800 max-w-md">
            <h4 className="font-bold mb-2">Keep up with Home237</h4>
            <p className="text-slate-400 text-sm mb-4">
              Product news and fresh listing alerts, straight to your inbox.
            </p>
            <form onSubmit={handleSubmit} className="flex items-center gap-2">
              <input
                type="email"
                placeholder="name@email.com"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
                className="flex-1 px-3 py-2.5 bg-slate-800 rounded text-white text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
              />
              <button type="submit" className="p-2.5 bg-blue-900 hover:bg-blue-800 rounded transition" aria-label="Subscribe">
                <Send size={16} />
              </button>
            </form>
            {message && <p className="text-green-400 text-xs mt-2">{message}</p>}
          </div>
        </div>
      </div>

      <div className="container-app py-8 flex flex-col sm:flex-row items-center justify-between gap-2 text-sm text-slate-400">
        <span>© {currentYear} Home237. All rights reserved.</span>
        <span>Built for Cameroon 🇨🇲</span>
      </div>
    </footer>
  );
}
