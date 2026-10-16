# net4sats installer — landing page

This file is the **single source** for the public install page. Deploy it at a stable
host (the `net4sats.com` root, or the repo's GitHub Pages) so the documented one-liner
resolves. `net4sats.com/install.sh` returns **404** today, which is why this exists.

## The page

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>net4sats — install TollGate on your router</title>
<meta name="description" content="Branded TollGate for your router. One command.">
<style>
 body{background:#0a0e27;color:#e6e8f0;font:16px/1.6 system-ui,sans-serif;
      max-width:44rem;margin:8vh auto;padding:0 1.25rem}
 h1{color:#f7931a;margin:0 0 .25rem}
 p.sub{color:#8892b0;margin:0 0 2rem}
 pre{background:#141834;border:1px solid #232a4d;border-radius:8px;padding:1rem;
     overflow-x:auto}
 code{color:#7abd7e}
 a{color:#f7931a}
 footer{margin-top:3rem;padding-top:1rem;border-top:1px solid #232a4d;color:#8892b0;
        font-size:.875rem}
</style>
</head>
<body>
<h1>net4sats</h1>
<p class="sub">TollGate on your router — metered internet, paid per use.</p>

<h2>Install</h2>
<pre><code>git clone https://github.com/net4sats/installer
cd installer &amp;&amp; sh install.sh</code></pre>

<p>Or, piping straight to a shell:</p>
<pre><code>curl -sL https://raw.githubusercontent.com/net4sats/installer/main/install.sh \\
  | N4S_REPO_SLUG=net4sats/installer sh</code></pre>

<p><small><code>N4S_REPO_SLUG</code> is required when piping because the script carries no
brand literal — the brand is data. From a clone no variable is needed.</small></p>

<h2>What this does</h2>
<p>Deploys the upstream TollGate stack to a supported OpenWrt router, branded as net4sats.
The wizard runs on this machine and talks to the router over your network.</p>

<footer>
 <p><strong>Built on TollGate</strong> — Copyright (C) the OpenTollGate contributors.
    Licensed GPL-3.0. See
    <a href="https://github.com/net4sats/installer/blob/main/LICENSE">LICENSE</a> and
    <a href="https://github.com/net4sats/installer/blob/main/NOTICE">NOTICE</a>.</p>
 <p>Source: <a href="https://github.com/net4sats/installer">github.com/net4sats/installer</a></p>
</footer>
</body>
</html>
```

## Where to deploy it

| Option | Host | Notes |
|---|---|---|
| A | `net4sats.com/` (root) | fixes the 404 for the documented host; needs DNS/host access |
| B | GitHub Pages on this repo | free, no DNS work; the raw one-liner already works regardless |

Either way the page must keep the **"Built on TollGate"** footer: attribution is a
licence obligation (GPL-3.0), and `tests/shell/test-licence-attribution.sh` asserts the
wording used elsewhere so all three surfaces agree.
