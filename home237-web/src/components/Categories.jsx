import { motion } from 'framer-motion';
import { Building2, Home, Hotel, BedDouble, Store, Warehouse } from 'lucide-react';

const categories = [
  { icon: Building2, label: 'Apartments', count: '420+ homes' },
  { icon: Home, label: 'Houses', count: '260+ homes' },
  { icon: BedDouble, label: 'Studios', count: '180+ homes' },
  { icon: Hotel, label: 'Guest houses', count: '90+ stays' },
  { icon: Store, label: 'Shops & offices', count: '75+ spaces' },
  { icon: Warehouse, label: 'Land & more', count: '40+ listings' },
];

export default function Categories() {
  return (
    <section className="py-24 bg-white" id="categories">
      <div className="container-app">
        <div className="section-head">
          <div className="eyebrow">Browse by type</div>
          <h2>Whatever you're looking for</h2>
          <p>From a single studio to a family house — find the right space in your city.</p>
        </div>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
          {categories.map((cat, i) => (
            <motion.a
              key={cat.label}
              href="/app"
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.06, duration: 0.5 }}
              className="group rounded-md border border-slate-100 bg-white p-6 shadow-xs hover:shadow-md hover:-translate-y-1 transition-all"
            >
              <div className="w-12 h-12 rounded-md bg-blue-50 flex items-center justify-center mb-4 group-hover:bg-blue-900 transition-colors">
                <cat.icon size={24} className="text-blue-900 group-hover:text-white transition-colors" />
              </div>
              <h3 className="font-bold text-ink-900 mb-1">{cat.label}</h3>
              <p className="text-sm text-slate-400">{cat.count}</p>
            </motion.a>
          ))}
        </div>
      </div>
    </section>
  );
}
