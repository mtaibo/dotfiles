// Renders assets/nvim/help.md into one HTML page with markdown-preview.nvim's
// own markdown-it and highlight.js, so it looks like the :md preview.
//   node help-render.js APP_DIR help.md out.html style.css...
const [app, md, out, ...styles] = process.argv.slice(2)
const fs = require('fs')
const req = (m) => require(app + '/node_modules/' + m)
const hljs = req('highlight.js')
const anchor = req('markdown-it-anchor')

const slug = (s) => s.toLowerCase().replace(/[^\w\s-]/g, '').trim().replace(/\s+/g, '-')
const markdown = req('markdown-it')({
  html: true,
  linkify: true,
  highlight: (str, lang) =>
    `<pre class="hljs"><code>${lang && hljs.getLanguage(lang)
      ? hljs.highlight(lang, str, true).value : markdown.utils.escapeHtml(str)}</code></pre>`,
}).use(anchor.default || anchor, { slugify: slug })

const source = fs.readFileSync(md, 'utf8')
const tokens = markdown.parse(source, {})
// The sidebar: every ## heading, with its ### ones below it.
const toc = []
tokens.forEach((t, i) => {
  if (t.type === 'heading_open' && (t.tag === 'h2' || t.tag === 'h3')) {
    const text = tokens[i + 1].content.replace(/`/g, '')
    toc.push(`<a class="${t.tag}" href="#${slug(text)}">${markdown.utils.escapeHtml(text)}</a>`)
  }
})
const css = styles.map((f) => fs.readFileSync(f, 'utf8')).join('\n')

fs.writeFileSync(out, `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Vim help</title>
<style>${css}</style>
</head>
<body>
<nav class="toc">${toc.join('\n')}</nav>
<main data-theme="dark"><div id="page-ctn"><section class="markdown-body">
${markdown.renderer.render(tokens, markdown.options, {})}
</section></div></main>
<script>
// Highlight the section being read in the sidebar.
const links = [...document.querySelectorAll('.toc a')]
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
