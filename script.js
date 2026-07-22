/* ============================================================
   Home237 — Site interactions
   ============================================================ */

const WEB_APP_URL = "app/";

document.addEventListener("DOMContentLoaded", () => {
  /* ── Footer year ── */
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = String(new Date().getFullYear());

  /* ── Sticky nav ── */
  const nav = document.getElementById("nav");
  if (nav) {
    const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 8);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
  }

  /* ── Mobile menu ── */
  const burger = document.getElementById("navBurger");
  const links = document.getElementById("navLinks");
  const actions = document.querySelector(".nav__actions");

  if (burger && links) {
    // Mirror desktop actions into the mobile drawer
    if (actions && !links.querySelector(".nav__mobile-actions")) {
      const mobileActions = document.createElement("div");
      mobileActions.className = "nav__mobile-actions";
      mobileActions.innerHTML = actions.innerHTML;
      links.appendChild(mobileActions);
    }

    const setMenuOpen = (open) => {
      burger.classList.toggle("open", open);
      links.classList.toggle("open", open);
      burger.setAttribute("aria-expanded", String(open));
      document.body.classList.toggle("nav-open", open);
    };

    const closeMenu = () => setMenuOpen(false);

    burger.addEventListener("click", () => {
      setMenuOpen(!burger.classList.contains("open"));
    });

    links.querySelectorAll("a").forEach((a) => a.addEventListener("click", closeMenu));

    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") closeMenu();
    });

    window.addEventListener("resize", () => {
      if (window.matchMedia("(min-width: 1025px)").matches) closeMenu();
    });
  }

  /* ── Category chips ── */
  const track = document.getElementById("categoryTrack");
  if (track) {
    track.querySelectorAll(".chip").forEach((chip) => {
      chip.addEventListener("click", () => {
        track.querySelectorAll(".chip").forEach((c) => c.classList.remove("is-active"));
        chip.classList.add("is-active");
      });
    });
  }

  /* ── Mark empty phone slots if images failed before JS ran ── */
  document.querySelectorAll(".phone-slot img.phone-img").forEach((img) => {
    if (!img.complete) return;
    if (img.naturalWidth === 0) {
      img.style.display = "none";
      img.parentElement.classList.add("is-empty");
    }
  });

  /* ── FAQ accordion ── */
  document.querySelectorAll(".faq-item").forEach((item) => {
    const btn = item.querySelector(".faq-item__q");
    const panel = item.querySelector(".faq-item__a");
    if (!btn || !panel) return;

    const setOpen = (open) => {
      item.classList.toggle("is-open", open);
      btn.setAttribute("aria-expanded", String(open));
      panel.style.maxHeight = open ? `${panel.scrollHeight}px` : "0px";
    };

    setOpen(item.classList.contains("is-open"));

    btn.addEventListener("click", () => {
      const willOpen = !item.classList.contains("is-open");
      document.querySelectorAll(".faq-item").forEach((other) => {
        if (other !== item) {
          other.classList.remove("is-open");
          other.querySelector(".faq-item__q")?.setAttribute("aria-expanded", "false");
          const otherPanel = other.querySelector(".faq-item__a");
          if (otherPanel) otherPanel.style.maxHeight = "0px";
        }
      });
      setOpen(willOpen);
    });
  });

  window.addEventListener("resize", () => {
    document.querySelectorAll(".faq-item.is-open .faq-item__a").forEach((panel) => {
      panel.style.maxHeight = `${panel.scrollHeight}px`;
    });
  });

  /* ── Newsletter form (footer) ── */
  const newsletterForm = document.getElementById("newsletterForm");
  const newsletterMsg = document.getElementById("newsletterMsg");
  if (newsletterForm) {
    newsletterForm.addEventListener("submit", (e) => {
      e.preventDefault();
      const input = newsletterForm.querySelector("input[type='email']");
      if (input && input.value.trim()) {
        if (newsletterMsg) newsletterMsg.textContent = "Thanks — you're on the list!";
        input.value = "";
      }
    });
  }

  /* ── Animated stat counters ── */
  const counters = document.querySelectorAll("[data-counter]");
  const animateCounter = (el) => {
    const target = parseFloat(el.getAttribute("data-counter") || "0");
    const suffix = el.getAttribute("data-suffix") || "";
    const decimals = parseInt(el.getAttribute("data-decimal") || "0", 10);
    const duration = 1200;
    const start = performance.now();

    const tick = (now) => {
      const progress = Math.min((now - start) / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3);
      const value = target * eased;
      el.textContent = value.toFixed(decimals) + suffix;
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
  };

  if (counters.length && "IntersectionObserver" in window) {
    const counterIo = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            animateCounter(entry.target);
            counterIo.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.4 }
    );
    counters.forEach((el) => counterIo.observe(el));
  } else {
    counters.forEach((el) => animateCounter(el));
  }

  /* ── Scroll reveal (fallback when GSAP unavailable) ── */
  const reveals = document.querySelectorAll(".reveal");
  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (prefersReduced) {
    reveals.forEach((el) => el.classList.add("in"));
  } else if (window.gsap && window.ScrollTrigger) {
    gsap.registerPlugin(ScrollTrigger);

    /* Ambient drifting orbs */
    document.querySelectorAll(".section-fx__orb").forEach((orb, i) => {
      const y = i % 2 === 0 ? 28 : -24;
      const x = i % 3 === 0 ? -18 : 22;
      gsap.to(orb, {
        x,
        y,
        duration: 6 + (i % 3) * 1.4,
        repeat: -1,
        yoyo: true,
        ease: "sine.inOut",
        delay: i * 0.35,
      });
    });

    /* Soft sweeping beams on dark / brand sections */
    document.querySelectorAll(".section-fx__beam").forEach((beam) => {
      gsap.fromTo(
        beam,
        { xPercent: -12, opacity: 0.25 },
        {
          xPercent: 12,
          opacity: 0.75,
          duration: 5.5,
          repeat: -1,
          yoyo: true,
          ease: "sine.inOut",
        }
      );
    });

    /* Scroll-triggered content reveals */
    reveals.forEach((el) => {
      gsap.fromTo(
        el,
        { autoAlpha: 0, y: 36 },
        {
          autoAlpha: 1,
          y: 0,
          duration: 0.85,
          ease: "power3.out",
          scrollTrigger: {
            trigger: el,
            start: "top 88%",
            once: true,
          },
          onStart: () => el.classList.add("in"),
        }
      );
    });

    /* Section atmosphere parallax */
    document.querySelectorAll(".has-fx").forEach((section) => {
      const fx = section.querySelector(".section-fx");
      if (!fx) return;
      gsap.to(fx, {
        yPercent: 8,
        ease: "none",
        scrollTrigger: {
          trigger: section,
          start: "top bottom",
          end: "bottom top",
          scrub: true,
        },
      });
    });

    /* Dark + CTA media punch-in */
    document.querySelectorAll("#payments .showcase__media, #download .cta__inner").forEach((el) => {
      gsap.fromTo(
        el,
        { autoAlpha: 0.4, scale: 0.96 },
        {
          autoAlpha: 1,
          scale: 1,
          duration: 1,
          ease: "power2.out",
          scrollTrigger: {
            trigger: el,
            start: "top 85%",
            once: true,
          },
        }
      );
    });
  } else if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e, i) => {
          if (e.isIntersecting) {
            setTimeout(() => e.target.classList.add("in"), (i % 4) * 70);
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -36px 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("in"));
  }
});
