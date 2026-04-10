document.addEventListener("DOMContentLoaded", () => {
  const sidebarLinks = document.querySelectorAll("#sidebar li a");
  const sections = Array.from(
    document.querySelectorAll("main h1, main h2, main h3, main h4"),
  );

  // スクロールスパイ機能
  const observerOptions = {
    root: null,

    rootMargin: "-20px 0px -80% 0px",
    threshold: 0,
  };

  const observer = new IntersectionObserver((entries) => {
    sidebarLinks.forEach((link) => link.classList.remove("active"));

    const visibleEntries = entries
      .filter((entry) => entry.isIntersecting)
      .sort((a, b) => a.boundingClientRect.top - b.boundingClientRect.top);

    if (visibleEntries.length > 0) {
      const topmostEntry = visibleEntries[0];
      const id = topmostEntry.target.getAttribute("id");
      if (id) {
        const activeLink = document.querySelector(
          `#sidebar li a[href="#${id}"]`,
        );
        if (activeLink) {
          activeLink.classList.add("active");
          // 親要素の開閉状態を調整
          let parent = activeLink.closest(".has-children");
          while (parent) {
            parent.classList.add("open");
            parent = parent.parentElement.closest(".has-children");
          }
        }
      }
    }
  }, observerOptions);

  sections.forEach((section) => observer.observe(section));

  // ライトボックス機能
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

  // コードコピー機能
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

  // サイドバー項目開閉機能
  document.querySelectorAll(".toggle-btn").forEach((btn) => {
    btn.addEventListener("click", (e) => {
      e.stopPropagation();
      const parent = btn.parentElement;
      parent.classList.toggle("open");
    });
  });

  // アンカーリンクのスムーズスクロール
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
