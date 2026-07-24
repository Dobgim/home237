import { motion } from 'framer-motion';
import { ShieldCheck, BadgeCheck, Lock, Headphones } from 'lucide-react';

const points = [
  { icon: ShieldCheck, title: 'Checked listings', text: 'Every home is reviewed by our team before it goes public.' },
  { icon: BadgeCheck, title: 'Verified agents', text: 'Identity and ownership checks earn agents a verified badge.' },
  { icon: Lock, title: 'Secure payments', text: 'Visit fees held in escrow and released only after you meet.' },
  { icon: Headphones, title: 'Real support', text: 'A human on our team is a message away when you need help.' },
];

export default function Trust() {
  return (
    <section className="py-16 bg-white border-b border-slate-100" id="trust">
      <div className="container-app">
        <p className="text-center text-xs font-bold uppercase tracking-wider text-slate-400 mb-10">
          Built on trust, from search to keys
        </p>
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
          {points.map((p, i) => (
            <motion.div
              key={p.title}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.08, duration: 0.6 }}
              className="rounded-md border border-slate-100 bg-slate-50 p-6 shadow-xs"
            >
              <div className="w-11 h-11 rounded-sm bg-blue-900/10 flex items-center justify-center mb-4">
                <p.icon size={22} className="text-blue-900" />
              </div>
              <h3 className="font-bold text-ink-900 mb-1">{p.title}</h3>
              <p className="text-sm text-slate-500 leading-relaxed">{p.text}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
