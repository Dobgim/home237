import { motion } from 'framer-motion';

export default function FinalCTA() {
  return (
    <section
      className="relative py-24 bg-gradient-to-br from-blue-900 to-blue-950 text-white overflow-hidden"
      id="download"
    >
      {/* Background elements */}
      <div className="absolute inset-0 -z-10">
        <div className="absolute top-0 right-0 w-96 h-96 bg-blue-500 rounded-full mix-blend-multiply filter blur-3xl opacity-30" />
        <div className="absolute bottom-0 left-0 w-96 h-96 bg-blue-500 rounded-full mix-blend-multiply filter blur-3xl opacity-30" />
      </div>

      <motion.div
        initial={{ opacity: 0, y: 20 }}
        whileInView={{ opacity: 1, y: 0 }}
        viewport={{ once: true }}
        className="container-app text-center"
      >
        <h2 className="text-4xl md:text-6xl font-black leading-tight mb-4 tracking-[-0.03em]">
          Start browsing today on the web
        </h2>
        <p className="text-lg md:text-xl text-blue-100 max-w-2xl mx-auto mb-12">
          Join thousands of Cameroonians searching, booking tours, and paying securely
          through Home237. Native mobile apps coming soon.
        </p>

        <div className="flex flex-col sm:flex-row items-center justify-center gap-4">
          <a href="/app" className="btn btn-white btn-primary-lg">
            Open web app
          </a>
          <a href="#features" className="btn btn-ghost-light btn-primary-lg">
            Learn more
          </a>
        </div>
      </motion.div>
    </section>
  );
}
