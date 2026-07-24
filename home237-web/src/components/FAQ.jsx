import { motion, AnimatePresence } from 'framer-motion';
import { useState } from 'react';
import { ChevronDown } from 'lucide-react';

const faqs = [
  {
    q: 'Do I pay to search for a home on Home237?',
    a: 'No. Searching, chatting with agents, and booking visits cost nothing for renters. You only pay the visit fee when you book a tour, and it is held safely until you meet.',
  },
  {
    q: 'What does "verified" actually mean?',
    a: 'Our team reviews each listing before it goes public, and agents complete identity and ownership checks. A verified badge appears on profiles and ads that pass.',
  },
  {
    q: 'How can I pay on Home237?',
    a: 'You can use MTN Mobile Money, Orange Money, or a bank transfer — the same options most people already use for everyday payments in Cameroon.',
  },
  {
    q: 'Can landlords manage several properties?',
    a: 'Yes. Add as many homes as you need, manage visits from one dashboard, and withdraw earnings whenever it suits you.',
  },
  {
    q: 'Where does Home237 operate today?',
    a: "We're live in Douala, Yaoundé, Buea, Bamenda, Bafoussam, and Limbe — with more cities on the roadmap.",
  },
];

function FAQItem({ q, a, isOpen, onToggle }) {
  return (
    <div className="border-b border-slate-200 last:border-b-0">
      <button
        onClick={onToggle}
        className="w-full flex items-center justify-between py-6 text-left hover:text-blue-900 transition"
        aria-expanded={isOpen}
      >
        <span className="font-semibold text-ink-900 flex-1 pr-4">{q}</span>
        <ChevronDown
          size={20}
          className={`shrink-0 transition-transform text-blue-900 ${isOpen ? 'rotate-180' : ''}`}
        />
      </button>
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            transition={{ duration: 0.3 }}
            className="overflow-hidden"
          >
            <p className="pb-6 text-slate-500 leading-relaxed">{a}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

export default function FAQ() {
  const [openIndex, setOpenIndex] = useState(0);

  return (
    <section className="py-24 bg-white" id="faq">
      <div className="container-app">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          className="section-head"
        >
          <div className="eyebrow">Help center</div>
          <h2>Questions we hear all the time</h2>
          <p>Still stuck? Our team is a message away.</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="max-w-2xl mx-auto"
        >
          {faqs.map((faq, i) => (
            <FAQItem
              key={i}
              {...faq}
              isOpen={openIndex === i}
              onToggle={() => setOpenIndex(openIndex === i ? -1 : i)}
            />
          ))}
        </motion.div>
      </div>
    </section>
  );
}
