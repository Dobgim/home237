import { motion } from 'framer-motion';
import { Search, CalendarCheck, Wallet, ShieldCheck, MessagesSquare, Star } from 'lucide-react';

const features = [
  {
    icon: Search,
    title: 'Search that fits Cameroon',
    text: 'Filter by city, neighbourhood, price and type — with real photos and honest details on every listing.',
  },
  {
    icon: CalendarCheck,
    title: 'Book visits in a tap',
    text: 'Pick a day, pay the visit fee into escrow, and get a QR pass. The agent is only paid after you actually meet.',
  },
  {
    icon: Wallet,
    title: 'Mobile Money, end to end',
    text: 'Pay visit fees, subscriptions and rent with MTN MoMo or Orange Money — no bank account required.',
  },
  {
    icon: ShieldCheck,
    title: 'Refunds if no-show',
    text: 'If the agent never shows up, your visit fee is returned to your phone — protection built into every booking.',
  },
  {
    icon: MessagesSquare,
    title: 'Chat before you commit',
    text: 'Message agents directly in the app to ask questions and agree on a time, all in one place.',
  },
  {
    icon: Star,
    title: 'Verified, not guesswork',
    text: 'Listings are reviewed and agents are checked, so the badge you see actually means something.',
  },
];

export default function Features() {
  return (
    <section className="py-24 bg-slate-50" id="features">
      <div className="container-app">
        <div className="section-head">
          <div className="eyebrow">Why Home237</div>
          <h2>Everything you need to rent with confidence</h2>
          <p>One app for searching, visiting, paying and staying protected.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {features.map((f, i) => (
            <motion.div
              key={f.title}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: (i % 3) * 0.08, duration: 0.6 }}
              className="rounded-md bg-white border border-slate-100 p-7 shadow-xs hover:shadow-md transition-shadow"
            >
              <div className="w-12 h-12 rounded-md bg-blue-900/10 flex items-center justify-center mb-5">
                <f.icon size={24} className="text-blue-900" />
              </div>
              <h3 className="text-lg font-bold text-ink-900 mb-2">{f.title}</h3>
              <p className="text-slate-500 leading-relaxed text-[15px]">{f.text}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
