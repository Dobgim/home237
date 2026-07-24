import { motion } from 'framer-motion';
import { Apple, Play } from 'lucide-react';

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.1, delayChildren: 0.2 },
  },
};

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.8 } },
};

export default function Hero() {
  return (
    <section className="relative pt-16 pb-24 md:pt-24 md:pb-32 bg-white overflow-hidden" id="top">
      {/* Background elements */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-0 right-0 w-96 h-96 bg-blue-100 rounded-full mix-blend-multiply filter blur-3xl opacity-30" />
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-blue-50 rounded-full mix-blend-multiply filter blur-3xl opacity-40" />
      </div>

      <motion.div
        className="container-app"
        variants={containerVariants}
        initial="hidden"
        animate="visible"
      >
        <motion.p variants={itemVariants} className="text-center text-blue-900 font-black text-lg mb-6">
          Home237
        </motion.p>

        <motion.h1
          variants={itemVariants}
          className="text-center text-5xl md:text-6xl font-black leading-tight mb-6 text-ink-900 tracking-[-0.03em]"
        >
          Your next place in<br />
          Cameroon starts <em className="not-italic text-blue-900">here</em>
        </motion.h1>

        <motion.p
          variants={itemVariants}
          className="text-center text-lg text-slate-500 max-w-2xl mx-auto mb-12"
        >
          Search real homes, schedule a visit, and settle rent with Mobile Money —
          built for how Cameroon actually rents.
        </motion.p>

        {/* App Store Buttons */}
        <motion.div
          variants={itemVariants}
          className="flex flex-col sm:flex-row items-center justify-center gap-4 mb-8"
        >
          <button
            disabled
            className="flex items-center gap-3 px-6 py-4 bg-ink-900 text-white rounded-sm opacity-65 cursor-not-allowed"
            aria-label="Download on the App Store - Coming soon"
          >
            <Apple size={22} />
            <div className="text-left">
              <div className="text-xs">Download on the</div>
              <div className="font-bold">App Store</div>
              <div className="text-xs text-green-400 font-bold uppercase tracking-wider">Coming soon</div>
            </div>
          </button>

          <button
            disabled
            className="flex items-center gap-3 px-6 py-4 bg-ink-900 text-white rounded-sm opacity-65 cursor-not-allowed"
            aria-label="Get it on Google Play - Coming soon"
          >
            <Play size={22} />
            <div className="text-left">
              <div className="text-xs">GET IT ON</div>
              <div className="font-bold">Google Play</div>
              <div className="text-xs text-green-400 font-bold uppercase tracking-wider">Coming soon</div>
            </div>
          </button>
        </motion.div>

        {/* Web App CTA */}
        <motion.div variants={itemVariants} className="flex flex-col items-center gap-4 mb-10">
          <p className="text-sm font-semibold text-slate-400 tracking-wider uppercase">
            Apps launching Q4 2026
          </p>
          <a href="https://home237.com" className="btn btn-primary btn-primary-lg">
            Explore website
          </a>
        </motion.div>

        {/* Payment methods strip */}
        <motion.div
          variants={itemVariants}
          className="flex flex-col items-center gap-3 mb-16"
        >
          <span className="text-xs font-semibold uppercase tracking-wider text-slate-400">
            Pay securely with
          </span>
          <div className="flex items-center gap-6">
            <img
              src="/images/mtn-mobile-money.png"
              alt="MTN Mobile Money"
              className="h-8 w-auto object-contain"
              loading="lazy"
            />
            <img
              src="/images/orange-money.png"
              alt="Orange Money"
              className="h-8 w-auto object-contain"
              loading="lazy"
            />
          </div>
        </motion.div>

        {/* Hero Image */}
        <motion.div variants={itemVariants} className="flex justify-center">
          <img
            src="/images/home237.png"
            alt="Home237 app interface showing property listings, booking system, and Mobile Money integration"
            className="max-w-2xl w-full rounded-lg shadow-lg"
            loading="lazy"
            onError={(e) => { e.currentTarget.style.display = 'none'; }}
          />
        </motion.div>
      </motion.div>
    </section>
  );
}
