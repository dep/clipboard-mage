/* ============================================================
   Clipboard Mage — marketing site interactions
   © 2026 Wandering Ghost LLC
   ============================================================ */

(function () {
  "use strict";

  var reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- twinkling stars ---------- */

  var starField = document.getElementById("stars");
  if (starField && !reducedMotion) {
    for (var i = 0; i < 70; i++) {
      var s = document.createElement("div");
      s.className = "star";
      s.style.left = Math.random() * 100 + "%";
      s.style.top = Math.random() * 100 + "%";
      s.style.animationDelay = Math.random() * 4 + "s";
      s.style.animationDuration = 3 + Math.random() * 4 + "s";
      var size = Math.random() < 0.2 ? 3 : 2;
      s.style.width = size + "px";
      s.style.height = size + "px";
      starField.appendChild(s);
    }
  }

  /* ---------- hero demo: the mage at work ---------- */

  var preview = document.getElementById("demo-preview");
  var instruction = document.getElementById("demo-instruction");
  var placeholder = document.getElementById("demo-placeholder");
  var status = document.getElementById("demo-status");
  var caption = document.getElementById("demo-caption");
  var enterKey = document.getElementById("demo-enter");

  if (!preview) return;

  var scenarios = [
    {
      caption: "Messy notes → clean markdown",
      clipboard:
        "meeting notes tues -- ok so launch date moved to sept 12,, sarah owns " +
        "the press release (draft by fri!!) and we STILL need budget signoff " +
        "from marco. oh and someone shld book the venue. dashboard redesign " +
        "is slipping to q4 probably",
      wish: "clean this up into markdown",
      result:
        "## Meeting Notes — Tuesday\n\n" +
        "**Launch:** moved to **Sept 12**\n\n" +
        "- Sarah owns the press release — *draft due Friday*\n" +
        "- Budget sign-off still needed from Marco\n" +
        "- Venue needs to be booked\n" +
        "- Dashboard redesign likely slips to Q4"
    },
    {
      caption: "A grumpy rant → a polite email",
      clipboard:
        "hey. this is the THIRD time the invoice is wrong. seriously?? " +
        "fix it and send a new one, i'm not paying until it's right.",
      wish: "turn this into a polite email",
      result:
        "Hi there,\n\n" +
        "I noticed the invoice contains an error — this is the third " +
        "occurrence, so I wanted to flag it directly. Could you please send " +
        "a corrected version when you have a moment?\n\n" +
        "I'll process payment as soon as the updated invoice arrives. " +
        "Thanks so much for your help!\n\n" +
        "Best regards"
    },
    {
      caption: "A paragraph → three crisp bullets",
      clipboard:
        "The quarterly report shows revenue grew 23% year over year, driven " +
        "primarily by the new subscription tier launched in March. Customer " +
        "churn dropped from 4.1% to 2.8%. However, infrastructure costs rose " +
        "31% and will need attention next quarter.",
      wish: "summarize in three bullets",
      result:
        "• Revenue up **23% YoY**, driven by the March subscription tier\n" +
        "• Churn improved from 4.1% → **2.8%**\n" +
        "• ⚠️ Infra costs rose **31%** — needs attention next quarter"
    }
  ];

  /* Minimal markdown-ish highlighter for the preview pane */
  function renderRich(text) {
    var esc = text
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
    return esc
      .replace(/^(#{1,3} .*)$/gm, '<span class="md-h">$1</span>')
      .replace(/\*\*([^*]+)\*\*/g, '<span class="md-b">**$1**</span>');
  }

  function sleep(ms) {
    return new Promise(function (r) { setTimeout(r, ms); });
  }

  function setStatus(label, cls) {
    status.textContent = label;
    status.className = "panel-status" + (cls ? " " + cls : "");
  }

  /* Types the wish into the instruction field, human-ish */
  async function typeWish(text) {
    placeholder.classList.add("hidden");
    for (var i = 0; i < text.length; i++) {
      instruction.textContent += text[i];
      await sleep(reducedMotion ? 0 : 34 + Math.random() * 46);
    }
  }

  /* Streams the result into the preview in token-sized chunks */
  async function streamResult(text) {
    var pos = 0;
    var shown = "";
    preview.classList.add("result");
    while (pos < text.length) {
      var chunk = 2 + Math.floor(Math.random() * 5);
      shown += text.slice(pos, pos + chunk);
      pos += chunk;
      preview.innerHTML = renderRich(shown);
      await sleep(reducedMotion ? 0 : 22 + Math.random() * 40);
    }
  }

  function flashEnter() {
    enterKey.classList.add("hot");
    setTimeout(function () { enterKey.classList.remove("hot"); }, 450);
  }

  async function playScenario(sc) {
    // 1. fresh clipboard appears
    caption.textContent = sc.caption;
    preview.classList.remove("result");
    preview.textContent = sc.clipboard;
    instruction.textContent = "";
    placeholder.classList.remove("hidden");
    setStatus("clipboard", "");
    await sleep(1600);

    // 2. the wish is typed
    await typeWish(sc.wish);
    await sleep(450);
    flashEnter();
    await sleep(350);

    // 3. streaming
    instruction.textContent = "";
    placeholder.classList.remove("hidden");
    setStatus("streaming…", "streaming");
    preview.textContent = "";
    await streamResult(sc.result);

    // 4. done — accept
    setStatus("✓ ready", "done");
    await sleep(1400);
    flashEnter();
    await sleep(300);
    setStatus("✓ copied", "done");
    await sleep(1700);
  }

  async function runDemo() {
    var idx = 0;
    // small initial beat so the page settles first
    await sleep(900);
    for (;;) {
      await playScenario(scenarios[idx]);
      idx = (idx + 1) % scenarios.length;
    }
  }

  runDemo();

  /* ---------- download link placeholder ---------- */

  var dmg = document.getElementById("dmg-link");
  if (dmg && dmg.getAttribute("href") === "#") {
    dmg.addEventListener("click", function (e) {
      e.preventDefault();
      var original = dmg.innerHTML;
      dmg.innerHTML = "🧙‍♂️ Coming soon — the mage is still studying the spell!";
      setTimeout(function () { dmg.innerHTML = original; }, 2600);
    });
  }
})();
