// Renders the :help guides (assets/nvim/guide.md, help.md…) into one HTML
// page with markdown-preview.nvim's own markdown-it and highlight.js, so it
// looks like the :md preview. A switch at the top of the sidebar picks the
// guide; the first one is shown by default.
//   node help-render.js APP_DIR out.html guide.md... style.css...
const [app, out, ...files] = process.argv.slice(2)
const fs = require('fs')
const path = require('path')
const req = (m) => require(app + '/node_modules/' + m)
const hljs = req('highlight.js')
const anchor = req('markdown-it-anchor')

// Anchors carry the guide's name, so the same heading in two guides
// doesn't clash.
let prefix = ''
const slug = (s) => prefix + '-' + s.toLowerCase().replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-')
const markdown = req('markdown-it')({
  html: true,
  linkify: true,
  highlight: (str, lang) =>
    `<pre class="hljs"><code>${lang && hljs.getLanguage(lang)
      ? hljs.highlight(lang, str, true).value : markdown.utils.escapeHtml(str)}</code></pre>`,
}).use(anchor.default || anchor, { slugify: (s) => slug(s) })
const esc = markdown.utils.escapeHtml

const guides = files.filter((f) => f.endsWith('.md')).map((file) => {
  // Nix store paths start with a hash: guide.md is "<hash>-guide.md".
  const id = path.basename(file, '.md').replace(/^[a-z0-9]{32}-/, '')
  prefix = id
  const tokens = markdown.parse(fs.readFileSync(file, 'utf8'), {})
  let title = id
  // The sidebar: every ## heading, with its ### ones below it.
  const toc = []
  tokens.forEach((t, i) => {
    const text = t.type === 'heading_open' && tokens[i + 1].content.replace(/`/g, '')
    if (text && t.tag === 'h1') title = text
    if (text && (t.tag === 'h2' || t.tag === 'h3')) {
      toc.push(`<a class="${t.tag}" href="#${slug(text)}">${esc(text)}</a>`)
    }
  })
  return { id, title, toc, html: markdown.renderer.render(tokens, markdown.options, {}) }
})
const css = files.filter((f) => f.endsWith('.css')).map((f) => fs.readFileSync(f, 'utf8')).join('\n')

fs.writeFileSync(out, `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vim help</title>
<style>${css}</style>
</head>
<body>
<nav class="toc">
<div class="guides">${guides.map((g) =>
  `<button data-guide="${g.id}">${esc(g.title)}</button>`).join('')}</div>
${guides.map((g) => `<div class="toc-list" data-guide="${g.id}">\n${g.toc.join('\n')}\n</div>`).join('\n')}
</nav>
<main data-theme="dark"><div id="page-ctn">
${guides.map((g) => `<section class="markdown-body" data-guide="${g.id}">\n${g.html}</section>`).join('\n')}
</div></main>
<script>
const ids = ${JSON.stringify(guides.map((g) => g.id))}
const panes = [...document.querySelectorAll('[data-guide]')]
// Show one guide; a link to a heading picks the guide it belongs to.
function show (id, top) {
  panes.forEach((p) => p.classList.toggle(p.tagName === 'BUTTON' ? 'active' : 'shown', p.dataset.guide === id))
  try { localStorage.setItem('guide', id) } catch (e) {}
  if (top) window.scrollTo(0, 0)
}
function fromHash () {
  const id = ids.find((g) => location.hash.startsWith('#' + g + '-'))
  if (id) {
    show(id)
    // The heading was hidden when the browser tried to scroll to it.
    const target = document.getElementById(decodeURIComponent(location.hash.slice(1)))
    if (target) target.scrollIntoView()
  }
  return id
}
let saved = null
try { saved = localStorage.getItem('guide') } catch (e) {}
fromHash() || show(ids.includes(saved) ? saved : ids[0])
window.addEventListener('hashchange', fromHash)
document.querySelectorAll('.guides button').forEach((b) => b.addEventListener('click', () => {
  history.replaceState(null, '', location.pathname)
  show(b.dataset.guide, true)
}))

// Highlight the section being read in the sidebar.
const links = [...document.querySelectorAll('.toc-list a')]
const spy = new IntersectionObserver((entries) => {
  for (const e of entries) {
    if (!e.isIntersecting) continue
    links.forEach((a) => a.classList.toggle('active', a.hash === '#' + e.target.id))
  }
}, { rootMargin: '0px 0px -75% 0px' })
document.querySelectorAll('.markdown-body h2, .markdown-body h3').forEach((h) => spy.observe(h))
</script>
</body>
</html>
`)
