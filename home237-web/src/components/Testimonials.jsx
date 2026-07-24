import { motion } from 'framer-motion';
import { Star, Quote } from 'lucide-react';

const testimonials = [
  {
    name: 'Aïcha M.',
    role: 'Renter · Douala',
    text: 'I found my apartment in Bonamoussadi in a weekend. Booking the visit and paying with MoMo felt safe — the agent only got paid after we met.',
  },
  {
    name: 'Jean-Paul K.',
    role: 'Agent · Yaoundé',
    text: 'Home237 brings me serious tenants. I manage all my visits from one dashboard and get paid straight to my mobile money.',
  },
  {
    name: 'Blessing N.',
    role: 'Renter · Buea',
    text: 'The verified badge gave me confidence. No more sending money before seeing a house — everything is handled inside the app.',
  },
];

export default function Testimonials() {
  return (
    <section className="py-24 bg-slate-50" id="testimonials">
      <div className="container-app">
        <div className="section-head">
          <div className="eyebrow">Stories</div>
          <h2>Loved by renters and agents</h2>
          <p>Real people finding and listing homes across Cameroon.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          {testimonials.map((t, i) => (
            <motion.figure
              key={t.name}
              initial={{ opacity: 0, y: 24 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1, duration: 0.6 }}
              className="rounded-md bg-white border border-slate-100 p-7 shadow-xs flex flex-col"
            >
              <Quote size={28} className="text-blue-900/20 mb-4" />
              <div className="flex gap-1 mb-4">
                {Array.from({ length: 5 }).map((_, s) => (
                  <Star key={s} size={16} className="text-green-600 fill-green-600" />
                ))}
              </div>
              <blockquote className="text-slate-600 leading-relaxed flex-1 text-[15px]">
                "{t.text}"
              </blockquote>
              <figcaption className="mt-6 flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-blue-900 text-white flex items-center justify-center font-bold">
                  {t.name.charAt(0)}
                </div>
                <div>
                  <div className="font-bold text-ink-900 text-sm">{t.name}</div>
                  <div className="text-xs text-slate-400">{t.role}</div>
                </div>
              </figcaption>
            </motion.figure>
          ))}
        </div>
      </div>
    </section>
  );
}
