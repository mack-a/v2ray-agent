# Pelican Bike SVG Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a single dependency-free HTML page showing a retro poster SVG animation of a pelican riding a bicycle.

**Architecture:** One semantic HTML document contains styles, an inline SVG scene, and a tiny control script. SVG groups separate scenery, bike, and pelican so CSS/SVG animations can target each independently.

**Tech Stack:** HTML5, CSS3 keyframes, inline SVG, vanilla JavaScript.

## Global Constraints

- No external assets or libraries.
- Use retro poster colors: paper yellow, ink navy, orange/coral accents.
- Support pause/resume and `prefers-reduced-motion`.
- Keep the page responsive without horizontal overflow.

### Task 1: Build the animated poster page

**Files:**
- Create: `pelican-bike.html`

**Interfaces:**
- Produces a standalone page with SVG scene and button `#toggle-motion`.

- [ ] Add document structure, responsive layout, background texture, title, and accessible button.
- [ ] Draw scenery with sun, clouds, layered hills, road, and grass using inline SVG.
- [ ] Draw bicycle with two wheel groups, frame, handlebar, seat, pedals, and rider connection points.
- [ ] Draw a recognizable pelican with body, long beak, head, wing, eye, feet, and legs.
- [ ] Add wheel rotation, cloud drift, body bob, and alternating leg/pedal motion via CSS keyframes.
- [ ] Add JavaScript to toggle a `.paused` class and update button label/ARIA state.
- [ ] Add reduced-motion media query that stops decorative movement while preserving the illustration.
- [ ] Verify by opening the file in a browser and checking animation, button behavior, and narrow viewport.
- [ ] Commit with `git add pelican-bike.html && git commit -m "feat: add animated pelican bicycle poster"`.
