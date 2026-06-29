/* ============================================================
   Home237 — Landing site interactions
   ============================================================ */

/**
 * Where the "Continue as Tenant / Landlord" buttons should send users.
 * Point this at your hosted Flutter web app (or a sign-up page).
 * The chosen role is appended as ?role=tenant|landlord.
 * Leave as "" to simply remember the choice and show a friendly message
 * (useful while the web app isn't deployed yet).
 */
const WEB_APP_URL = "app/"; // the Flutter web app, bundled at /app/ next to this page

document.addEventListener("DOMContentLoaded", () => {
  /* ---- Footer year ---- */
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---- Sticky nav shadow on scroll ---- */
  const nav = document.getElementById("nav");
  const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 8);
  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });

  /* ---- Mobile menu ---- */
  const burger = document.getElementById("navBurger");
  const links = document.getElementById("navLinks");
  const closeMenu = () => {
    burger.classList.remove("open");
    links.classList.remove("open");
    burger.setAttribute("aria-expanded", "false");
  };
  burger.addEventListener("click", () => {
    const open = burger.classList.toggle("open");
    links.classList.toggle("open", open);
    burger.setAttribute("aria-expanded", String(open));
  });
  links.querySelectorAll("a").forEach((a) => a.addEventListener("click", closeMenu));

  /* ---- Scroll reveal ---- */
  const reveals = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((e, i) => {
          if (e.isIntersecting) {
            // tiny stagger for grouped elements
            setTimeout(() => e.target.classList.add("in"), (i % 4) * 70);
            io.unobserve(e.target);
          }
        });
      },
      { threshold: 0.12, rootMargin: "0px 0px -40px 0px" }
    );
    reveals.forEach((el) => io.observe(el));
  } else {
    reveals.forEach((el) => el.classList.add("in"));
  }

  /* ---- Role selection ---- */
  const roleCards = document.querySelectorAll(".role-card");
  const note = document.getElementById("rolesNote");

  // Restore a previously chosen role (nice touch for returning visitors)
  const savedRole = localStorage.getItem("home237_role");

  const go = (role) => {
    localStorage.setItem("home237_role", role);
    if (WEB_APP_URL) {
      window.location.href = `${WEB_APP_URL}?role=${encodeURIComponent(role)}`;
    } else if (note) {
      const label = role === "landlord" ? "Landlord" : "Tenant";
      note.hidden = false;
      note.textContent = `Great choice — you're set up as a ${label}! 🎉 The full experience arrives with our app, launching soon.`;
      document.getElementById("app").scrollIntoView({ behavior: "smooth" });
    }
  };

  roleCards.forEach((card) => {
    const role = card.dataset.role;
    if (savedRole === role) card.classList.add("selected");

    card.addEventListener("click", () => {
      roleCards.forEach((c) => {
        c.classList.remove("selected");
        c.setAttribute("aria-pressed", "false");
      });
      card.classList.add("selected");
      card.setAttribute("aria-pressed", "true");
      go(role);
    });
  });

  /* ---- Notify-me form (mobile app) ---- */
  const form = document.getElementById("notifyForm");
  const emailInput = document.getElementById("notifyEmail");
  const msg = document.getElementById("notifyMsg");

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const email = emailInput.value.trim();
    const valid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
    if (!valid) {
      msg.style.color = "#fca5a5";
      msg.textContent = "Please enter a valid email address.";
      return;
    }

    // Store locally so nothing is lost before a real backend is wired up.
    const list = JSON.parse(localStorage.getItem("home237_waitlist") || "[]");
    if (!list.includes(email)) list.push(email);
    localStorage.setItem("home237_waitlist", JSON.stringify(list));

    msg.style.color = "#34d399";
    msg.textContent = "You're on the list! We'll email you the moment the app drops. 🚀";
    form.reset();

    /* To collect these for real, point the form at a service like Formspree:
       form.action = "https://formspree.io/f/your-id"; form.method = "POST";
       and remove e.preventDefault(). */
  });
});
