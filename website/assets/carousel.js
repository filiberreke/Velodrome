for (const carousel of document.querySelectorAll("[data-carousel]")) {
  const controls = carousel.querySelector(".hero-controls");
  const track = carousel.querySelector(".hero-slides");
  const slides = [...track.children];
  const dots = [...controls.querySelectorAll("[data-slide]")];
  const dotLabels = dots.map((dot) => dot.getAttribute("aria-label"));
  const motion = matchMedia("(prefers-reduced-motion: reduce)");
  let current = 0;
  let playing = !motion.matches;
  let onscreen = false;
  let hovered = false;
  let timer;
  let touchStart;
  let pointerToggle;

  function updateDots() {
    dots.forEach((dot, index) => {
      if (index !== current) {
        dot.removeAttribute("aria-current");
        dot.removeAttribute("title");
        dot.setAttribute("aria-label", dotLabels[index]);
        return;
      }
      dot.setAttribute("aria-current", "true");
      if (motion.matches) {
        dot.removeAttribute("title");
        dot.setAttribute("aria-label", dotLabels[index]);
        return;
      }
      const action = playing ? controls.dataset.pause : controls.dataset.resume;
      dot.title = action;
      dot.setAttribute("aria-label", `${dotLabels[index]}. ${action}`);
    });
  }

  function show(index) {
    slides[current].hidden = true;
    current = (index + slides.length) % slides.length;
    slides[current].hidden = false;
    updateDots();
  }

  function schedule() {
    clearInterval(timer);
    if (playing && onscreen && !hovered && !document.hidden) {
      timer = setInterval(() => show(current + 1), 6000);
    }
  }

  function setPlaying(enabled) {
    playing = enabled && !motion.matches;
    track.setAttribute("aria-live", playing ? "off" : "polite");
    updateDots();
    schedule();
  }

  function navigate(index) {
    setPlaying(false);
    if (index !== current) show(index);
  }

  // Focus can pause rotation between the pointer press and click.
  controls.addEventListener("pointerdown", (event) => {
    pointerToggle = event.target.closest("[aria-current]") ? !playing : undefined;
  });
  controls.addEventListener("pointercancel", () => { pointerToggle = undefined; });
  controls.addEventListener("click", (event) => {
    const button = event.target.closest("[data-step], [data-slide]");
    if (!button) return;
    if (button.hasAttribute("data-step")) {
      navigate(current + Number(button.dataset.step));
    } else {
      const index = Number(button.dataset.slide);
      if (index === current && !motion.matches) {
        setPlaying(event.detail && pointerToggle !== undefined ? pointerToggle : !playing);
      } else {
        navigate(index);
      }
    }
    pointerToggle = undefined;
  });
  controls.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    navigate(current + (event.key === "ArrowLeft" ? -1 : 1));
  });
  carousel.addEventListener("focusin", (event) => {
    if (!carousel.contains(event.relatedTarget) || track.contains(event.target)) setPlaying(false);
  });
  carousel.addEventListener("pointerenter", (event) => {
    if (event.pointerType === "mouse") {
      hovered = true;
      schedule();
    }
  });
  carousel.addEventListener("pointerleave", (event) => {
    if (event.pointerType === "mouse") {
      hovered = false;
      schedule();
    }
  });

  track.addEventListener("touchstart", (event) => {
    touchStart = event.touches.length === 1 ? event.touches[0] : undefined;
  }, { passive: true });
  track.addEventListener("touchcancel", () => { touchStart = undefined; });
  track.addEventListener("touchend", (event) => {
    const touch = event.changedTouches[0];
    if (!touchStart || touch.identifier !== touchStart.identifier) return;
    const dx = touch.clientX - touchStart.clientX;
    const dy = touch.clientY - touchStart.clientY;
    touchStart = undefined;
    if (Math.abs(dx) < 45 || Math.abs(dx) < Math.abs(dy) * 1.5) return;
    if (event.cancelable) event.preventDefault();
    navigate(current + (dx < 0 ? 1 : -1));
  });

  new IntersectionObserver(([entry]) => {
    onscreen = entry.isIntersecting;
    schedule();
  }).observe(carousel);
  document.addEventListener("visibilitychange", schedule);
  motion.addEventListener("change", (event) => {
    if (event.matches) setPlaying(false);
    else updateDots();
  });
  setPlaying(playing);
  controls.hidden = false;
}
