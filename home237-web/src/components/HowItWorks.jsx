import { motion } from 'framer-motion';
import { Search, CalendarCheck, KeyRound } from 'lucide-react';

const steps = [
  {
    icon: Search,
    step: '01',
    title: 'Find your home',
    text: 'Browse verified listings across 6+ cities and shortlist the ones you love.',
  },
  {
    icon: CalendarCheck,
    step: '02',
    title: 'Book a visit',
    text: 'Choose a day and pay the visit fee into escrow. Show your QR pass when you meet the agent.',
  },
  {
    icon: KeyRound,
    step: '03',
    title: 'Move in',
    text: 'Agree, settle rent with Mobile Money, and get your keys — with a record of every payment.',
  },
];

export default function HowItWorks() {
  return (
    <section className="py-24 bg-white" id="how">
      <div className="container-app">
        <div className="section-head">
          <div className="eyebrow">How it works</div>
          <h2>Three steps to your next home</h2>
          <p>Simple, safe, and built for the way Cameroon rents.</p>
        </div>

        <div className="relative grid grid-cols-1 md:grid-cols-3 gap-8">
          {steps.map((s, i) => (
            <motion.div
              key={s.step}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.12, duration: 0.6 }}
              className="relative text-center"
            >
              <div className="mx-auto w-16 h-16 rounded-lg bg-blue-900 text-white flex items-center justify-center mb-6 shadow-blue-lg">
                <s.icon size={28} />
              </div>
              <span className="block text-xs font-black tracking-widest text-blue-900 mb-2">
                STEP {s.step}
              </span>
              <h3 className="text-xl font-bold text-ink-900 mb-2">{s.title}</h3>
              <p className="text-slate-500 max-w-xs mx-auto leading-relaxed">{s.text}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
