import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';
import { useInView } from 'react-intersection-observer';

function Counter({ target, suffix = '', decimal = 0 }) {
  const [count, setCount] = useState(0);
  const { ref, inView } = useInView({ threshold: 0.5, triggerOnce: true });

  useEffect(() => {
    if (!inView) return;
    const increment = target / 60;
    let current = 0;
    const timer = setInterval(() => {
      current += increment;
      if (current >= target) {
        setCount(target);
        clearInterval(timer);
      } else {
        setCount(decimal > 0 ? parseFloat(current.toFixed(decimal)) : Math.floor(current));
      }
    }, 30);
    return () => clearInterval(timer);
  }, [inView, target, decimal]);

  return (
    <strong ref={ref} className="text-4xl md:text-5xl font-black text-blue-900">
      {count}
      {suffix}
    </strong>
  );
}

const stats = [
  { count: 6, suffix: '+', label: 'Active cities' },
  { count: 1000, suffix: '+', label: 'Homes on the platform' },
  { count: 90, suffix: '+', label: 'Partner agents' },
  { count: 4.9, suffix: '/5', decimal: 1, label: 'User score' },
];

export default function Stats() {
  return (
    <section className="py-20 bg-slate-50" id="stats">
      <div className="container-app">
        <div className="grid grid-cols-2 md:grid-cols-4 gap-8">
          {stats.map((stat, i) => (
            <motion.div
              key={i}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: i * 0.08 }}
              className="text-center"
            >
              <Counter target={stat.count} suffix={stat.suffix} decimal={stat.decimal} />
              <p className="text-slate-500 mt-3 text-sm font-medium">{stat.label}</p>
            </motion.div>
          ))}
        </div>
      </div>
    </section>
  );
}
