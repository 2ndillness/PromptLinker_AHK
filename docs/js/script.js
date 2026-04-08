document.addEventListener("DOMContentLoaded", () => {
  const sidebarLinks = document.querySelectorAll("#sidebar li a");
  const sections = Array.from(
    document.querySelectorAll("main h1, main h2, main h3, main h4"),
  );

  // Scroll Spy Logic
  const observerOptions = {
    root: null,
    rootMargin: "-10% 0px -80% 0px",
    threshold: 0,
  };

  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        const id = entry.target.getAttribute("id");
        if (id) {
          sidebarLinks.forEach((link) => {
            link.classList.remove("active");
            if (link.getAttribute("href") === `#${id}`) {
              link.classList.add("active");
              // Ensure parent is open
              let parent = link.closest(".has-children");
              while (parent) {
                parent.classList.add("open");
                parent = parent.parentElement.closest(".has-children");
              }
            }
          });
        }
      }
    });
  }, observerOptions);

  sections.forEach((section) => observer.observe(section));

  // Lightbox Logic
  const lightbox = document.createElement("div");
  lightbox.id = "lightbox";
  document.body.appendChild(lightbox);
  const lightboxImg = document.createElement("img");
  lightbox.appendChild(lightboxImg);

  document.querySelectorAll("main img").forEach((img) => {
    img.addEventListener("click", () => {
      lightboxImg.src = img.src;
      lightbox.style.display = "flex";
    });
  });

  lightbox.addEventListener("click", () => {
    lightbox.style.display = "none";
  });

  // Copy Button Logic
  document.querySelectorAll("main pre").forEach((pre) => {
    const btn = document.createElement("button");
    btn.className = "copy-btn";
    btn.innerText = "Copy";
    pre.appendChild(btn);

    btn.addEventListener("click", () => {
      const code = pre.querySelector("code").innerText;
      navigator.clipboard.writeText(code).then(() => {
        btn.innerText = "Copied!";
        btn.classList.add("copied");
        setTimeout(() => {
          btn.innerText = "Copy";
          btn.classList.remove("copied");
        }, 2000);
      });
    });
  });

  // Toggle Sidebar Items
  document.querySelectorAll(".toggle-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const parent = btn.parentElement;
      parent.classList.toggle("open");
    });
  });

  // Smooth scroll for anchors
  sidebarLinks.forEach((link) => {
    link.addEventListener("click", (e) => {
      const href = link.getAttribute("href");
      if (href.startsWith("#")) {
        e.preventDefault();
        const targetId = href.substring(1);
        const targetElement = document.getElementById(targetId);
        if (targetElement) {
          window.scrollTo({
            top: targetElement.offsetTop - 20,
            behavior: "smooth",
          });
        }
      }
    });
  });
});
