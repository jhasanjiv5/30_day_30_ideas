#!/usr/bin/env python3
"""Builds the lab-notebook README and its hand-drawn SVG figures.

Edit the SPECIMENS list below, then run from the repository root:

    cd /path/to/30_day_30_ideas && python3 docs/lab/notebook.py

It rewrites README.md and docs/lab/*.svg. Standard library only.
"""
from __future__ import annotations

import math
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LAB = ROOT / "docs" / "lab"

# ---------------------------------------------------------------------------
# Data. maturity: 1-5, research: 1-5, business: 1-10 (None = not rated yet).
# ---------------------------------------------------------------------------
MATURITY = {
    1: ("💡", "Spark", "idea or template only"),
    2: ("✏️", "Sketch", "screens run on mock data; core feature partial"),
    3: ("⚗️", "Prototype", "core feature works end to end; documented"),
    4: ("🧫", "MVP", "tests + diagrams/screenshots; ready for real users to try"),
    5: ("🚀", "Field-tested", "used for real outside the simulator"),
}

TAGS = {
    "apple": "🍎 Apple-native",
    "web": "🌐 Web",
    "ai": "🧠 AI systems",
    "health": "❤️ Health & wellbeing",
    "industry": "🏭 Industrial",
    "game": "🎮 Game",
    "learn": "📚 Learning",
    "media": "🎬 Media & audio",
    "security": "🛡️ Security & privacy",
    "culture": "🪔 Culture & heritage",
    "biz": "💼 Small business",
}

SPECIMENS = [
    dict(day=1, name="30 Days · 30 Apps", short="Idea Calendar", path="Idea_calendar",
         tags=["web"], maturity=4, research=1, business=2,
         pitch="A public, read-only gallery for this very challenge: a calendar of ideas, live snapshots and usage notes, in English and German.",
         verdict="Useful plumbing for the challenge itself; little market outside it.",
         next="Auto-import each project's README and screenshots so the gallery updates itself."),
    dict(day=2, name="PlantLens", short="PlantLens", path="PlantLens/PlantLens",
         tags=["apple", "ai"], maturity=3, research=2, business=8,
         pitch="Point your iPhone at a plant: get its name and a health check from Gemini 2.5 Flash.",
         verdict="Proven demand (gardening apps earn well), but crowded; win on diagnosis quality and care reminders.",
         next="Add a care calendar and a 'what's wrong with my leaf' follow-up chat."),
    dict(day=3, name="German–Hindi Flashcards", short="Flashcards", path="GermanHindiFlashcards",
         tags=["web", "learn"], maturity=3, research=2, business=8,
         pitch="Goethe A1–C2 German vocabulary with Hindi translations, pronunciation and Anki-style spaced repetition.",
         verdict="An underserved language pair with a fast-growing audience of Indians moving to Germany.",
         next="Exam-mode mock tests per Goethe level and an offline mobile build."),
    dict(day=4, name="ArtLens", short="ArtLens", path="ArtLens/ArtLens",
         tags=["apple", "ai"], maturity=2, research=3, business=3,
         pitch="Photograph a sketch or canvas and get stage-aware feedback from Apple's on-device model.",
         verdict="Lovely for hobbyists, but artists rarely pay for critique apps.",
         next="Track one artwork across sessions and show progress over time."),
    dict(day=5, name="AmbientRAG Architect & Autonomous Interface", short="AmbientRAG", path="AmbientRAGInterface",
         tags=["web", "ai"], maturity=3, research=4, business=9,
         pitch="A blueprint and workbench for RAG systems where the UI never touches the vector database or model directly.",
         verdict="Every company is building RAG; a clean, swappable reference architecture sells as consulting and templates.",
         next="Package it as a starter kit with evals and one-click deploy."),
    dict(day=6, name="MacOSMediaCenter", short="Media Center", path="MacOSMediaCenter",
         tags=["apple", "media"], maturity=3, research=1, business=4,
         pitch="A cinematic, lean-back streaming dashboard for the Mac with vibe search and an in-app web player.",
         verdict="Pleasant, but it wraps other companies' services, which limits what it can charge for.",
         next="Cross-service 'continue watching' and remote control from the iPhone."),
    dict(day=7, name="CookLens", short="CookLens", path="CookLens",
         tags=["apple", "ai"], maturity=2, research=2, business=8,
         pitch="Photograph your ingredients and get recipe ideas, using Apple's on-device image classifier.",
         verdict="Big everyday market; needs better ingredient recognition than a general classifier gives.",
         next="Swap rule-based recipes for on-device generation and add a pantry list."),
    dict(day=8, name="LuminaLightCamera", short="Lumina", path="LuminaLightCamera",
         tags=["apple", "media"], maturity=2, research=1, business=2,
         pitch="A camera viewfinder that shows an estimated room-light reading and a one-tap exposure boost.",
         verdict="A neat feature, but the built-in Camera app already covers most of it.",
         next="Suggest where to move the lamp, not just how bright the room is."),
    dict(day=9, name="Daybreak", short="Daybreak", path="Daybreak",
         tags=["apple"], maturity=3, research=2, business=6,
         pitch="A morning briefing and prioritised task list built from your reminders.",
         verdict="People pay for good planners, but switching from their current one is hard.",
         next="Ship the widget target (the source is already there)."),
    dict(day=10, name="AquaWatch", short="AquaWatch", path="AquaWatch",
         tags=["apple", "health"], maturity=2, research=3, business=5,
         pitch="Apple Watch notices a drinking gesture, asks you to confirm, and logs the water to Apple Health.",
         verdict="Clever, low-friction tracking; a niche inside an already-crowded hydration market.",
         next="Measure gesture-detection accuracy on real wrists before adding features."),
    dict(day=11, name="SovereignSocial", short="SovereignSocial", path="SovereignSocial",
         tags=["apple", "biz", "security"], maturity=2, research=2, business=7,
         pitch="On-device social-media strategy for small business owners, with a biometric lock and encrypted vault.",
         verdict="Small businesses pay for marketing help; privacy is a fresh angle in that space.",
         next="Finish Secure Enclave key storage and add post scheduling."),
    dict(day=12, name="SpatialRoomAI", short="SpatialRoom", path="SpatialRoomAI",
         tags=["apple", "ai"], maturity=2, research=3, business=7,
         pitch="Capture a room, get a declutter checklist, compare a new layout and estimate the decor budget.",
         verdict="Home-improvement buyers spend money; furniture retailers could pay for referrals.",
         next="Use RoomPlan for real measurements instead of sample layouts."),
    dict(day=13, name="FastShopper '84", short="FastShopper", path="FastShopperGame",
         tags=["apple", "game"], maturity=3, research=1, business=1,
         pitch="A 2D arcade shopping-cart dash through 1984 Christmas Eve department stores, with an AI concierge.",
         verdict="Fun seasonal game; one-off games rarely earn back their time.",
         next="Keep it as a portfolio piece."),
    dict(day=14, name="LightMeinKraft", short="LightMeinKraft", path="LightMeinKraft",
         tags=["apple", "game"], maturity=3, research=2, business=1,
         pitch="A native macOS voxel holiday adventure with its own lighting, physics and 8-bit audio.",
         verdict="An impressive engine exercise; its mechanics borrow heavily from an existing game.",
         next="Give it original mechanics and art before showing it publicly."),
    dict(day=15, name="ErgoPods", short="ErgoPods", path="ErgoPods",
         tags=["apple", "health"], maturity=2, research=3, business=6,
         pitch="Posture tracking from AirPods head motion, with Apple Health metrics and physio guidance.",
         verdict="Real pain point for desk workers; would need clinical credibility to charge well.",
         next="Validate the slouch signal against a physiotherapist's assessment."),
    dict(day=16, name="SnippetAI", short="SnippetAI", path="SnippetAI",
         tags=["apple", "ai", "media"], maturity=2, research=3, business=9,
         pitch="Import a video and let on-device vision plus Apple Intelligence pick the highlights, then edit and export a reel.",
         verdict="Short-form video is a huge, paying market; creators want faster editing.",
         next="Add audio cues (laughs, cheers) to the highlight picker and one-tap vertical export."),
    dict(day=17, name="Sanctuary", short="Sanctuary", path="Sanctuary",
         tags=["apple", "health"], maturity=3, research=3, business=5,
         pitch="A calm evening check-in that listens and mirrors your feelings instead of giving advice.",
         verdict="Wellbeing apps sell, but mental-health products carry heavy trust and safety duties.",
         next="Add clear crisis-help routing and a weekly mood reflection."),
    dict(day=18, name="KineScanVisionOS", short="KineScan", path="KineScanVisionOS",
         tags=["apple", "industry"], maturity=2, research=3, business=4,
         pitch="A machining-centre digital twin you can walk around in Apple Vision Pro.",
         verdict="Great demo for trade fairs; the headset's install base is still small.",
         next="Feed it live machine telemetry instead of scripted data."),
    dict(day=19, name="FieldTwin", short="FieldTwin", path="FieldTwin",
         tags=["apple", "industry", "ai"], maturity=2, research=4, business=10,
         pitch="Inspect equipment in a room-scale digital twin, score telemetry on the device, and approve risk-tiered maintenance.",
         verdict="Maintenance teams have budgets and real downtime costs; on-device scoring helps sell to sites with strict IT rules.",
         next="Pilot with one facility and real sensor feeds."),
    dict(day=20, name="ColdTwin", short="ColdTwin", path="ColdTwin",
         tags=["apple", "industry"], maturity=3, research=3, business=8,
         pitch="Explains fridge and freezer temperature trends and suggests the next low-risk check.",
         verdict="Spoiled stock is expensive for restaurants and pharmacies; a clear, honest advisor has buyers.",
         next="Connect to a real temperature logger and add alert rules."),
    dict(day=21, name="Mithila Panji Search", short="Panji Search", path="mithila-panji-search",
         tags=["web", "culture"], maturity=4, research=4, business=1,
         pitch="Search digitised Mithila genealogy records (Panji) across Roman and Devanagari spellings, with cited family links.",
         verdict="High cultural and research value; a community project, not a business.",
         next="Invite community corrections with source checks."),
    dict(day=22, name="PersonalVoiceStudio", short="Voice Studio", path="PersonalVoiceStudio",
         tags=["apple", "media", "security"], maturity=4, research=3, business=1,
         pitch="Record your own voice profile and synthesise speech entirely offline on a Mac, behind a consent gate.",
         verdict="Thoughtfully built, but the operating system now offers a similar feature for free.",
         next="Pair it with Video Studio as one offline creator kit."),
    dict(day=23, name="PersonalVideoStudio", short="Video Studio", path="PersonalVideoStudio",
         tags=["apple", "media"], maturity=4, research=2, business=1,
         pitch="Turn portraits, a script, your narration and music into an .mp4, all offline on the Mac.",
         verdict="Solid craft; competes with mature free editors.",
         next="Pair it with Voice Studio as one offline creator kit."),
    dict(day=24, name="RankLab Autopsy", short="RankLab", path="ranklab-autopsy",
         tags=["web", "learn", "ai"], maturity=3, research=4, business=3,
         pitch="A workbench for recommender systems: recall-vs-latency trade-offs, position-bias fixes and simulated A/B tests.",
         verdict="Great teaching tool; data scientists are used to free courses.",
         next="Add unit tests for the maths (NDCG, CUPED, χ²), then package it as a paid workshop or interview-prep module."),
    dict(day=25, name="Ensemble", short="Ensemble", path="Ensemble",
         tags=["apple", "ai", "media"], maturity=4, research=4, business=4,
         pitch="Apple TV picks what the whole room will enjoy from everyone's phones, and recaps what you missed.",
         verdict="A showstopper demo that works best as a platform feature; streaming apps own the data.",
         next="Use it as a portfolio piece or pitch it to a streaming service."),
    dict(day=26, name="Prod Preview", short="Prod Preview", path="prod-preview",
         tags=["web", "ai", "biz"], maturity=4, research=3, business=7,
         pitch="Turns a cloud proof-of-concept into a plain-language scorecard, What-If simulator and sign-off for non-technical stakeholders.",
         verdict="Clear B2B buyer (consultancies, platform teams); needs deep cloud access, which slows security reviews.",
         next="Add AWS and Azure providers and a read-only connector that is easy to approve."),
    dict(day=27, name="Kavach", short="Kavach", path="kavach",
         tags=["security", "ai"], maturity=5, research=4, business=8,
         pitch="A local guard inside AI coding sessions that stops secrets, PII, prompt injection and risky commands before they reach a cloud model.",
         verdict="AI-agent security is a fast-growing budget line; tuning out false alarms decides adoption.",
         next="Cut false positives on everyday developer commands (seen in real use) and add team policies."),
    dict(day=28, name="Saathi", short="Saathi", path="Saathi",
         tags=["apple", "media", "culture", "security"], maturity=4, research=4, business=6,
         pitch="A friend in your AirPods who tells you about the place you're walking through, then turns the walk into a podcast. Location never stored.",
         verdict="Distinctive and privacy-first; tourism boards are natural partners, but consumer audio guides are hard to monetise.",
         next="Run a real walk on iPhone + Apple Watch and tune the companion's timing."),
    dict(day=29, name="Drishya", short="Drishya", path="drishya",
         tags=["web", "ai", "learn"], maturity=4, research=4, business=6,
         pitch="Turns a research paper into a narrated, cited video podcast with diagrams and charts, plus grounded Q&A, in English and 11 Indian languages.",
         verdict="Strong demand and real differentiation in citations; video costs are high and big players are close.",
         next="Measure cost per video and offer a university or publisher tier."),
    dict(day=30, name="To be decided", short="???", path=None,
         tags=[], maturity=None, research=None, business=None,
         pitch="Tomorrow's experiment. The bench is cleared.",
         verdict="—", next="—"),
]

# ---------------------------------------------------------------------------
# Sketchy SVG helpers
# ---------------------------------------------------------------------------
PAPER = "#fbf7ec"
GRID = "#d9e4ef"
INK = "#2b2d42"
PENCIL = "#6c6f7d"
MARKER = {
    "hi": "#2a9d8f",   # 8-10
    "mid": "#e9c46a",  # 5-7
    "lo": "#e76f51",   # 1-4
    "none": "#b8b8c8",
}
FONT = "'Segoe Print','Bradley Hand','Chalkboard SE','Comic Sans MS','Marker Felt',cursive"


def tier(score: int | None) -> str:
    if score is None:
        return "none"
    return "hi" if score >= 8 else "mid" if score >= 5 else "lo"


def svg_open(w: int, h: int, title: str) -> str:
    return f"""<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img" aria-label="{title}">
<title>{title}</title>
<defs>
  <filter id="sketch" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="7" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="3.2"/>
  </filter>
  <filter id="wobble" x="-5%" y="-5%" width="110%" height="110%">
    <feTurbulence type="turbulence" baseFrequency="0.02" numOctaves="1" seed="3" result="n"/>
    <feDisplacementMap in="SourceGraphic" in2="n" scale="1.8"/>
  </filter>
  <pattern id="grid" width="20" height="20" patternUnits="userSpaceOnUse">
    <path d="M20 0H0V20" fill="none" stroke="{GRID}" stroke-width="1"/>
  </pattern>
  <pattern id="hatch" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
    <line x1="0" y1="0" x2="0" y2="6" stroke="{INK}" stroke-opacity=".18" stroke-width="2"/>
  </pattern>
</defs>
<style>
  text {{ font-family: {FONT}; fill: {INK}; }}
  .pencil {{ fill: {PENCIL}; }}
  .bubble {{ animation: rise 6s ease-in infinite; opacity: 0; }}
  @keyframes rise {{ 0% {{ transform: translateY(0); opacity: 0; }} 15% {{ opacity: .8; }} 100% {{ transform: translateY(-120px); opacity: 0; }} }}
  .blink {{ animation: blink 1.2s steps(2) infinite; }}
  @keyframes blink {{ 50% {{ opacity: 0; }} }}
  .float {{ animation: float 4s ease-in-out infinite; transform-box: fill-box; transform-origin: center; }}
  @keyframes float {{ 50% {{ transform: translateY(-4px) rotate(-1deg); }} }}
</style>
<rect width="{w}" height="{h}" fill="{PAPER}"/>
<rect width="{w}" height="{h}" fill="url(#grid)"/>
"""


def rough_rect(x, y, w, h, rng, stroke=INK, fill="none", sw=2.2, passes=2) -> str:
    out = []
    for p in range(passes):
        j = lambda: rng.uniform(-2.2, 2.2)
        pts = [(x + j(), y + j()), (x + w + j(), y + j()), (x + w + j(), y + h + j()), (x + j(), y + h + j())]
        d = "M" + " L".join(f"{a:.1f} {b:.1f}" for a, b in pts) + " Z"
        out.append(f'<path d="{d}" fill="{fill if p == 0 else "none"}" stroke="{stroke}" stroke-width="{sw if p == 0 else sw * .5}" stroke-linejoin="round" opacity="{1 if p == 0 else .55}"/>')
    return "\n".join(out)


def rough_line(x1, y1, x2, y2, rng, stroke=INK, sw=2, dash=None) -> str:
    mx, my = (x1 + x2) / 2 + rng.uniform(-3, 3), (y1 + y2) / 2 + rng.uniform(-3, 3)
    da = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<path d="M{x1:.1f} {y1:.1f} Q{mx:.1f} {my:.1f} {x2:.1f} {y2:.1f}" fill="none" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round"{da}/>'


def rough_circle(cx, cy, r, rng, fill, stroke=INK) -> str:
    pts = []
    for i in range(14):
        a = i / 14 * 2 * math.pi
        rr = r + rng.uniform(-1.4, 1.4)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d = "M" + " L".join(f"{a:.1f} {b:.1f}" for a, b in pts) + " Z"
    return f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="2" stroke-linejoin="round"/>'


def esc(s: str) -> str:
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


# ---------------------------------------------------------------------------
# Figure 1: banner
# ---------------------------------------------------------------------------
def banner() -> str:
    rng = random.Random(30)
    w, h = 1000, 300
    s = [svg_open(w, h, "30 Ideas in 30 Days: a lab notebook")]
    # margin line + punch holes like a notebook page
    s.append(f'<line x1="70" y1="0" x2="70" y2="{h}" stroke="#e5989b" stroke-width="2"/>')
    for y in (60, 150, 240):
        s.append(f'<circle cx="32" cy="{y}" r="11" fill="#efe9da" stroke="{PENCIL}" stroke-width="1.5"/>')
    s.append('<g filter="url(#wobble)">')
    s.append(f'<text x="100" y="105" font-size="58" font-weight="700">30 Ideas · 30 Days</text>')
    s.append(f'<text x="104" y="150" font-size="26" class="pencil">a lab notebook of apps, prototypes &amp; happy accidents</text>')
    s.append(rough_line(100, 120, 640, 118, rng, stroke="#e76f51", sw=4))
    s.append('</g>')
    # stats scribbles
    rated = [p for p in SPECIMENS if p["business"] is not None]
    avg = sum(p["business"] for p in rated) / len(rated)
    mvps = sum(1 for p in rated if (p["maturity"] or 0) >= 4)
    stats = [(f"{len(rated)}", "experiments logged"), (f"{mvps}", "reached MVP or beyond"), (f"{avg:.1f}", "avg. business score")]
    for i, (big, small) in enumerate(stats):
        x = 110 + i * 190
        s.append(f'<g filter="url(#sketch)">{rough_rect(x, 185, 165, 80, rng, fill="#ffffff")}</g>')
        s.append(f'<text x="{x + 16}" y="232" font-size="36" font-weight="700">{big}</text>')
        s.append(f'<text x="{x + 16}" y="254" font-size="14" class="pencil">{small}</text>')
    # flask with bubbles
    fx = 830
    s.append('<g filter="url(#sketch)">')
    s.append(f'<path d="M{fx - 22} 70 L{fx - 22} 140 L{fx - 80} 250 Q{fx - 85} 268 {fx - 65} 268 L{fx + 65} 268 Q{fx + 85} 268 {fx + 80} 250 L{fx + 22} 140 L{fx + 22} 70 Z" fill="#ffffff" stroke="{INK}" stroke-width="3"/>')
    s.append(f'<path d="M{fx - 63} 215 L{fx + 63} 215 L{fx + 80} 250 Q{fx + 85} 266 {fx + 65} 266 L{fx - 65} 266 Q{fx - 85} 266 {fx - 80} 250 Z" fill="#2a9d8f" opacity=".75"/>')
    s.append(f'<path d="M{fx - 63} 215 L{fx + 63} 215 L{fx + 80} 250 Q{fx + 85} 266 {fx + 65} 266 L{fx - 65} 266 Q{fx - 85} 266 {fx - 80} 250 Z" fill="url(#hatch)"/>')
    s.append(f'<rect x="{fx - 30}" y="58" width="60" height="14" rx="3" fill="#efe9da" stroke="{INK}" stroke-width="2.5"/>')
    s.append('</g>')
    for i in range(7):
        bx = fx + rng.uniform(-40, 40)
        r = rng.uniform(4, 9)
        s.append(f'<circle class="bubble" cx="{bx:.0f}" cy="245" r="{r:.1f}" fill="none" stroke="{INK}" stroke-width="1.6" style="animation-delay:{i * 0.85:.2f}s"/>')
    s.append(f'<text x="{fx - 105}" y="40" font-size="15" class="pencil" transform="rotate(-6 {fx} 40)">ideas → products (bubbling…)</text>')
    s.append("</svg>\n")
    return "\n".join(s)


# ---------------------------------------------------------------------------
# Figure 2: the lab bench (maturity × business, bubble = research)
# ---------------------------------------------------------------------------
def bench() -> str:
    rng = random.Random(7)
    w, h = 1000, 640
    L, R, T, B = 110, 720, 70, 560
    s = [svg_open(w, h, "Lab bench: how finished each project is versus its business value")]
    s.append(f'<text x="{L}" y="44" font-size="28" font-weight="700" filter="url(#wobble)">Fig. 1 · The lab bench</text>')
    # quadrant washes
    midx = L + (R - L) * (3.5 - 0.5) / 5
    midy = T + (B - T) * (10 - 6.5) / 10
    washes = [
        (midx, T, R - midx, midy - T, "#2a9d8f", "SHIP IT 🚀"),
        (L, T, midx - L, midy - T, "#e9c46a", "FUND THE BUILD 💸"),
        (midx, midy, R - midx, B - midy, "#8ecae6", "POLISHED PORTFOLIO ✨"),
        (L, midy, midx - L, B - midy, "#e76f51", "BACK TO THE NOTEBOOK 📓"),
    ]
    for x, y, ww, hh, col, label in washes:
        s.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{ww:.0f}" height="{hh:.0f}" fill="{col}" opacity=".10"/>')
        ty = y + 24 if y == T else (y + hh - 12 if x == L else B - (B - T) * 0.27)
        anchor = "end" if (x != L and y != T) else "start"
        tx = x + ww - 12 if anchor == "end" else x + 10
        s.append(f'<text x="{tx:.0f}" y="{ty:.0f}" font-size="15" class="pencil" opacity=".9" text-anchor="{anchor}">{label}</text>')
    s.append('<g filter="url(#sketch)">')
    s.append(rough_line(L, B, R + 10, B, rng, sw=2.5))
    s.append(rough_line(L, B, L, T - 10, rng, sw=2.5))
    s.append(rough_line(midx, T, midx, B, rng, stroke=PENCIL, sw=1.4, dash="6 6"))
    s.append(rough_line(L, midy, R, midy, rng, stroke=PENCIL, sw=1.4, dash="6 6"))
    s.append('</g>')
    for m in range(1, 6):
        x = L + (R - L) * (m - 0.5) / 5
        icon, label, _ = MATURITY[m]
        s.append(f'<text x="{x:.0f}" y="{B + 26}" font-size="14" text-anchor="middle">{icon} {label}</text>')
    s.append(f'<text x="{(L + R) / 2:.0f}" y="{B + 58}" font-size="17" text-anchor="middle" font-weight="700">how finished is it? →</text>')
    for v in (1, 4, 7, 10):
        y = B - (B - T) * (v - 0.5) / 10
        s.append(f'<text x="{L - 14}" y="{y + 5:.0f}" font-size="14" text-anchor="end">{v}</text>')
    s.append(f'<text x="40" y="{(T + B) / 2:.0f}" font-size="17" font-weight="700" text-anchor="middle" transform="rotate(-90 40 {(T + B) / 2:.0f})">business value →</text>')

    # place bubbles; jitter collisions in a small spiral
    placed: list[tuple[float, float, float]] = []
    for p in SPECIMENS:
        if p["business"] is None:
            continue
        bx = L + (R - L) * (p["maturity"] - 0.5) / 5
        by = B - (B - T) * (p["business"] - 0.5) / 10
        r = 9 + p["research"] * 3.2
        ang, rad = rng.uniform(0, 6.28), 0.0
        x, y = bx, by
        while any((x - a) ** 2 + (y - b) ** 2 < (r + c + 2) ** 2 for a, b, c in placed):
            ang += 0.9
            rad += 2.2
            x, y = bx + rad * math.cos(ang), by + rad * math.sin(ang) * 0.2
        placed.append((x, y, r))
        col = MARKER[tier(p["business"])]
        s.append(f'<g class="float" style="animation-delay:{p["day"] * 0.13:.2f}s">')
        s.append(f'<title>Day {p["day"]} · {esc(p["name"])} — maturity {p["maturity"]}/5, research {p["research"]}/5, business {p["business"]}/10</title>')
        s.append(rough_circle(x, y, r, rng, col))
        s.append(f'<text x="{x:.1f}" y="{y + 5:.1f}" font-size="{13 if r < 20 else 15}" font-weight="700" text-anchor="middle">{p["day"]}</text>')
        s.append('</g>')

    # key on the right
    kx = 750
    s.append(f'<text x="{kx}" y="86" font-size="17" font-weight="700">Specimen key</text>')
    for i, p in enumerate(SPECIMENS[:-1]):
        y = 108 + i * 16
        col = MARKER[tier(p["business"])]
        s.append(f'<circle cx="{kx + 6}" cy="{y - 4}" r="5" fill="{col}" stroke="{INK}" stroke-width="1"/>')
        s.append(f'<text x="{kx + 18}" y="{y}" font-size="12.5">{p["day"]:>2} · {esc(p["short"])}</text>')
    s.append(f'<text x="{kx}" y="{108 + 29 * 16 + 6}" font-size="12" class="pencil">bubble size = research value</text>')
    s.append("</svg>\n")
    return "\n".join(s)


# ---------------------------------------------------------------------------
# Figure 3: the 30-day specimen tray
# ---------------------------------------------------------------------------
def tray() -> str:
    rng = random.Random(11)
    cols, rows = 6, 5
    cw, ch = 150, 104
    w, h = cols * cw + 60, rows * ch + 110
    s = [svg_open(w, h, "Specimen tray: all 30 days coloured by business value")]
    s.append(f'<text x="30" y="46" font-size="28" font-weight="700" filter="url(#wobble)">Fig. 2 · The specimen tray</text>')
    s.append(f'<text x="{w - 30}" y="46" font-size="14" class="pencil" text-anchor="end">one jar per day · colour = business value · flask = maturity</text>')
    for i, p in enumerate(SPECIMENS):
        c, r = i % cols, i // cols
        x, y = 30 + c * cw, 70 + r * ch
        col = MARKER[tier(p["business"])]
        rot = rng.uniform(-2.5, 2.5)
        s.append(f'<g transform="rotate({rot:.1f} {x + cw / 2} {y + ch / 2})">')
        s.append(f'<g filter="url(#sketch)">{rough_rect(x + 6, y + 6, cw - 14, ch - 14, rng, fill=col if p["business"] else "#ffffff", sw=2)}</g>')
        if p["business"] is None:
            s.append(f'<rect x="{x + 6}" y="{y + 6}" width="{cw - 14}" height="{ch - 14}" fill="url(#hatch)"/>')
        s.append(f'<text x="{x + 16}" y="{y + 30}" font-size="13" font-weight="700" opacity=".7">DAY {p["day"]}</text>')
        name = p["short"]
        s.append(f'<text x="{x + 16}" y="{y + 56}" font-size="{17 if len(name) <= 12 else 14}" font-weight="700">{esc(name)}</text>')
        if p["business"] is None:
            s.append(f'<text x="{x + 16}" y="{y + 80}" font-size="15" class="blink">brewing…</text>')
        else:
            icon = MATURITY[p["maturity"]][0]
            s.append(f'<text x="{x + 16}" y="{y + 82}" font-size="15">{p["business"]}/10  {icon}</text>')
        s.append('</g>')
    ly = h - 22
    for j, (k, lab) in enumerate((("hi", "8–10 strong"), ("mid", "5–7 promising"), ("lo", "1–4 hobby"))):
        lx = 30 + j * 180
        s.append(f'<rect x="{lx}" y="{ly - 13}" width="18" height="16" fill="{MARKER[k]}" stroke="{INK}" stroke-width="1.5"/>')
        s.append(f'<text x="{lx + 26}" y="{ly}" font-size="14">{lab}</text>')
    s.append("</svg>\n")
    return "\n".join(s)


# ---------------------------------------------------------------------------
# README
# ---------------------------------------------------------------------------
def meter(n: int | None, total: int, on: str, off: str = "·") -> str:
    if n is None:
        return "—"
    return on * n + off * (total - n)


def bar10(n: int | None) -> str:
    return "—" if n is None else "▰" * n + "▱" * (10 - n) + f" {n}/10"


def link(p) -> str:
    return f"[{p['name']}](./{p['path']}/README.md)" if p["path"] else p["name"]


def card(p) -> str:
    icon, mlabel, mdesc = MATURITY[p["maturity"]]
    tags = " ".join(f"`{TAGS[t]}`" for t in p["tags"])
    return f"""<details>
<summary><b>Day {p['day']} · {p['name']}</b> &nbsp; {bar10(p['business'])} &nbsp; {icon} {mlabel}</summary>

> {p['pitch']}

| 🧪 Maturity | 🔬 Research value | 💰 Business value |
| :--- | :--- | :--- |
| {icon} **{mlabel}** ({p['maturity']}/5)<br><sub>{mdesc}</sub> | {meter(p['research'], 5, '🔬', '▫️')} {p['research']}/5 | {bar10(p['business'])} |

**Lab verdict:** {p['verdict']}<br>
**Next experiment:** {p['next']}<br>
**Tags:** {tags} &nbsp;·&nbsp; 📂 {link(p)}

</details>
"""


def readme() -> str:
    rated = [p for p in SPECIMENS if p["business"] is not None]
    by_biz = sorted(rated, key=lambda p: (-p["business"], -p["maturity"], -p["research"], p["day"]))
    top = [p for p in by_biz if p["business"] >= 8]
    mid = [p for p in by_biz if 5 <= p["business"] <= 7]
    low = [p for p in by_biz if p["business"] <= 4]

    def pick(cond, key, n=4):
        return ", ".join(f"[Day {p['day']} · {p['short']}](#day-{p['day']})" for p in sorted(filter(cond, rated), key=key)[:n])

    tag_counts = {}
    for p in rated:
        for t in p["tags"]:
            tag_counts[t] = tag_counts.get(t, 0) + 1
    pie = "\n".join(f'    "{TAGS[t]}" : {n}' for t, n in sorted(tag_counts.items(), key=lambda kv: -kv[1]))

    rows = "\n".join(
        f"| {i} | {p['day']} | {link(p)} | {MATURITY[p['maturity']][0]} {MATURITY[p['maturity']][1]} | {meter(p['research'], 5, '●', '○')} | {bar10(p['business'])} |"
        for i, p in enumerate(by_biz, 1)
    )
    nxt = next(p for p in SPECIMENS if p["business"] is None)

    def shelf(items):
        return "\n".join(f'<a id="day-{p["day"]}"></a>\n{card(p)}' for p in items)

    legend = "\n".join(f"| {MATURITY[m][0]} | **{MATURITY[m][1]}** | {MATURITY[m][2]} |" for m in range(1, 6))

    return f"""<!-- Generated by docs/lab/notebook.py — edit the data there, then run it from the repository root: python3 docs/lab/notebook.py -->
<p align="center"><img src="docs/lab/banner.svg" alt="30 Ideas · 30 Days — a lab notebook" width="100%"></p>

<p align="center">
<b>One idea a day. One build a day. Every result logged, measured and honestly judged.</b><br>
<sub>Challenge dates: October 26 – November 24, 2026 · 🧪 field notes by the challenge author</sub>
</p>

---

## 🧭 Pick your path through the lab

<details>
<summary><b>💼 I'm an investor or founder:</b> show me what could make money</summary>

Start with the top shelf: {pick(lambda p: p['business'] >= 8, lambda p: (-p['business'], -p['maturity']))}.<br>
Closest to launch (business ≥ 7 **and** MVP or better): {pick(lambda p: p['business'] >= 7 and p['maturity'] >= 4, lambda p: (-p['business'], -p['maturity']))}.
</details>

<details>
<summary><b>🔬 I'm a researcher or engineer:</b> show me the interesting technical ideas</summary>

Highest research value: {pick(lambda p: p['research'] >= 4, lambda p: (-p['research'], -p['maturity']), 6)}.<br>
Themes: on-device AI with no cloud, citation-grounded generation, privacy-by-design sensing, and digital twins.
</details>

<details>
<summary><b>👀 I just want to see something cool</b></summary>

Try {pick(lambda p: p['day'] in (25, 28, 29, 18), lambda p: p['day'])}: a room-aware TV, a friend in your AirPods, papers turned into videos, and a factory machine you can walk around in Vision Pro.
</details>

<details>
<summary><b>🛠️ I want to build on one of these</b></summary>

Most complete codebases (tests, diagrams, screenshots): {pick(lambda p: p['maturity'] >= 4, lambda p: (-p['maturity'], -p['business']), 6)}.<br>
Each card below ends with a **Next experiment**: a good first contribution.
</details>

---

## 📏 How each experiment is measured

Every specimen is scored on three dials:

| Dial | Scale | What it asks |
| :--- | :---: | :--- |
| 🧪 **Maturity** | 1–5 | How finished is the build? Measured from the code: tests, docs, screenshots, real-world runs. |
| 🔬 **Research value** | 1–5 | How novel or instructive is the technique, regardless of money? |
| 💰 **Business value** | 1–10 | Is there a buyer, a reason to pay, and room in the market? |

<details>
<summary>🧪 What the maturity flasks mean</summary>

| Flask | Stage | Meaning |
| :---: | :--- | :--- |
{legend}
</details>

---

## 🧫 Fig. 1 · The lab bench

<p align="center"><img src="docs/lab/bench.svg" alt="Scatter of each project: maturity on the horizontal axis, business value on the vertical axis, bubble size shows research value" width="100%"></p>

> **How to read it:** right = more finished, up = more valuable, bigger bubble = more research value.
> Top-right is **ship it**; top-left needs **funding to finish the build**.
> Open the image on its own to hover over a bubble for its full name and scores.

## 🗂️ Fig. 2 · The specimen tray

<p align="center"><img src="docs/lab/tray.svg" alt="Grid of all 30 days, each coloured by business value" width="100%"></p>

## 🥧 What the lab worked on

```mermaid
pie showData title Experiments by theme (a project can have several)
{pie}
```

---

## 🏆 The leaderboard

| Rank | Day | Specimen | 🧪 Maturity | 🔬 Research | 💰 Business |
| ---: | ---: | :--- | :--- | :---: | :--- |
{rows}
| — | {nxt['day']} | _{nxt['name']}_ | 🫙 brewing… | — | — |

---

## 🔍 Specimen cards

> Click any card to open it: pitch, scores, the lab's verdict, and the next experiment to run.

### 🥇 Top shelf: strong business case (8–10)

{shelf(top)}
### 🥈 Middle shelf: promising, with conditions (5–7)

{shelf(mid)}
### 📦 Bottom drawer: great for learning and portfolios (1–4)

{shelf(low)}
### 🫙 Still brewing

<details>
<summary><b>Day {nxt['day']} · {nxt['name']}</b> &nbsp; 🫙 brewing…</summary>

> {nxt['pitch']}
</details>

---

## 📝 Lab notes

- **Scores are judgement calls**, made on {len(rated)} projects in late November 2026 from each project's code and README. Business value weighs the buyer, willingness to pay, competition and distribution; it says nothing about how fun or well made a project is.
- **Maturity is measured from the code**: tests, documentation, screenshots or frames, and whether it has run outside a simulator. Only Kavach has been used for real so far.
- Every project lives in its own folder here; none has a published standalone repository yet.

<details>
<summary>🛠️ How this page is made</summary>

All scores, pitches and verdicts live in [`docs/lab/notebook.py`](docs/lab/notebook.py). Edit the `SPECIMENS` list and run it **from the repository root** (the folder that holds this README):

```bash
cd 30_day_30_ideas && python3 docs/lab/notebook.py
```

It regenerates this README and the hand-drawn figures in `docs/lab/` (plain SVG, no dependencies).
</details>

<p align="center"><sub>🧪 Made in a messy lab, one day at a time.</sub></p>
"""


def main() -> None:
    LAB.mkdir(parents=True, exist_ok=True)
    (LAB / "banner.svg").write_text(banner(), encoding="utf-8")
    (LAB / "bench.svg").write_text(bench(), encoding="utf-8")
    (LAB / "tray.svg").write_text(tray(), encoding="utf-8")
    (ROOT / "README.md").write_text(readme(), encoding="utf-8")
    print("wrote README.md and docs/lab/{banner,bench,tray}.svg")


if __name__ == "__main__":
    main()
