import { motion } from 'framer-motion';

const shots = [
  { src: '/images/design.png', label: 'Browse verified listings' },
  { src: '/images/design1.png', label: 'Book visits & pay securely' },
  { src: '/images/design2.png', label: 'Manage everything in one place' },
];

export default function Showcase() {
  return (
    <section className="py-24 bg-white" id="showcase">
      <div className="container-app">
        <div className="section-head">
          <div className="eyebrow">Take a look</div>
          <h2>Home237 in action</h2>
          <p>A closer look at searching, booking, and paying — the Home237 way.</p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
          {shots.map((shot, i) => (
            <motion.figure
              key={shot.src}
              initial={{ opacity: 0, y: 28 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.1, duration: 0.6 }}
              className="group"
            >
              <div className="overflow-hidden rounded-lg border border-slate-100 bg-slate-50 shadow-md">
                <img
                  src={shot.src}
                  alt={shot.label}
                  className="w-full h-auto object-cover transition-transform duration-500 group-hover:scale-[1.03]"
                  loading="lazy"
                  onError={(e) => { e.currentTarget.closest('figure').style.display = 'none'; }}
                />
              </div>
              <figcaption className="mt-4 text-center text-sm font-semibold text-slate-500">
                {shot.label}
              </figcaption>
            </motion.figure>
          ))}
        </div>
      </div>
    </section>
  );
}
