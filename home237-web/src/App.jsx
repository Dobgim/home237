import Header from './components/Header';
import Hero from './components/Hero';
import Trust from './components/Trust';
import Stats from './components/Stats';
import Categories from './components/Categories';
import Features from './components/Features';
import HowItWorks from './components/HowItWorks';
import Showcase from './components/Showcase';
import Testimonials from './components/Testimonials';
import FAQ from './components/FAQ';
import FinalCTA from './components/FinalCTA';
import Footer from './components/Footer';

export default function App() {
  return (
    <div className="bg-white">
      <Header />
      <main>
        <Hero />
        <Trust />
        <Stats />
        <Categories />
        <Features />
        <HowItWorks />
        <Showcase />
        <Testimonials />
        <FAQ />
        <FinalCTA />
      </main>
      <Footer />
    </div>
  );
}
