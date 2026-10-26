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
 /* overflow-wrap rather than word-break: it breaks only when the line would
    otherwise overflow, and prefers real opportunities (slashes in a URL) over
    splitting a filename down the middle. */
 /* Slightly smaller code text so the 85-character installer URL plus its trailing
    line-continuation fits the 44rem column. At 16px the URL consumed the full width
    and the lone backslash soft-wrapped onto its own visual line, which reads as if
    the continuation were a separate command. */
 pre{background:#141834;border:1px solid #232a4d;border-radius:8px;padding:1rem;
     font-size:.8125rem;white-space:pre-wrap;overflow-wrap:anywhere}
 code{color:#7abd7e}
 a{color:#f7931a}
 /* A 63-character npub in a table cell starves the other column and turns the row
    into a tall ribbon of two-word lines. Tables stay for short cells; anything
    carrying an npub is a stacked block instead. */
 table{width:100%;border-collapse:collapse;margin:1rem 0}
 th,td{text-align:left;padding:.4rem .6rem;border-bottom:1px solid #232a4d;
       vertical-align:top}
 th{color:#8892b0;font-weight:600}
 .acct{margin:1rem 0;padding:.75rem 1rem;background:#141834;
       border:1px solid #232a4d;border-radius:8px}
 .acct .who{color:#e6e8f0;font-weight:600}
 .acct .what{color:#8892b0;font-size:.875rem}
 .acct code{display:block;margin-top:.4rem;word-break:break-all;font-size:.875rem}
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
<pre><code>curl -sL https://raw.githubusercontent.com/net4sats/installer/main/install.sh \
  | N4S_REPO_SLUG=net4sats/installer sh</code></pre>

<p><small><code>N4S_REPO_SLUG</code> is required when piping because the script carries no
brand literal — the brand is data. From a clone no variable is needed.</small></p>

<h2>What this does</h2>
<p>Deploys the upstream TollGate stack to a supported OpenWrt router, branded as net4sats.
The wizard runs on this machine and talks to the router over your network.</p>

<h2>Supported routers</h2>
<p>The upstream feed publishes both <code>.apk</code> (OpenWrt 25.12) and <code>.ipk</code>
(OpenWrt 24.10) for the <code>aarch64_cortex-a53 / mediatek-filogic</code> target.</p>
<table>
 <tr><th>Router</th><th>Status</th></tr>
 <tr><td>GL.iNet GL-MT3000</td><td>validated — in-place upgrade verified</td></tr>
 <tr><td>GL.iNet GL-MT6000</td><td>validated — in-place upgrade verified</td></tr>
 <tr><td>COMFAST CF-WR632AX</td><td>asset published, <em>not yet installed on hardware</em></td></tr>
</table>
<p><small>Any other device on the same target with enough flash should work, but only the
rows above have been checked. If your router is not listed, do not flash it blind.</small></p>

<h2>Support</h2>
<p>Support runs on Nostr — no email, no ticket system. Both accounts are public and
answer in the open, so the next person with your problem can find the answer.</p>
<div class="acct">
 <div class="who">net4sats</div>
 <div class="what">this installer, the brand, a deploy that failed</div>
 <a href="https://njump.me/npub19pxkqvlna77masux62kjq56m7s065769mx7jjxltglqy2rcxk6jqrqe7gq"><code>npub19pxkqvlna77masux62kjq56m7s065769mx7jjxltglqy2rcxk6jqrqe7gq</code></a>
</div>

<div class="acct">
 <div class="who">TollGate</div>
 <div class="what">the protocol, the router module, the firmware itself</div>
 <a href="https://njump.me/npub1zzt0d0s2f4lsanpd7nkjep5r79p7ljq7aw37eek64hf0ef6v0mxqgwljrv"><code>npub1zzt0d0s2f4lsanpd7nkjep5r79p7ljq7aw37eek64hf0ef6v0mxqgwljrv</code></a>
</div>
<p><small>Paste the npub into any Nostr client if you would rather not open a link. A
report is far more useful with your router model and the exact command you ran.</small></p>

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

**Deployment access (blocker, measured 2026-10-25):** the Pages host is NOT writable by the
automation identity — `felixfelix-bot` holds `push:false, pull:true` on
`net4sats/net4sats.github.io`, vs `admin:true, push:true` on this repo. That is why a
fully-written page has been sitting here while `net4sats.github.io` and its canonical
`docs.net4sats.cash` both still serve a 2013-byte "Coming soon!" stub. Deploying needs a
push grant on the Pages repo, or an operator copying this HTML to it as `index.html`.

**Support channel:** Nostr, decided 2026-10-25. Two accounts, both looked up rather than
guessed:

- net4sats — `npub19pxkqvlna77masux62kjq56m7s065769mx7jjxltglqy2rcxk6jqrqe7gq`
  (kind-0 profile: name `net4sats`, about "Share Your WiFi, Earn Bitcoin", website
  `https://net4sats.cash/`; the npub↔pubkey encoding was round-trip verified)
- TollGate — `npub1zzt0d0s2f4lsanpd7nkjep5r79p7ljq7aw37eek64hf0ef6v0mxqgwljrv`
  (kind-0 profile: name `TollGate`, about "Discussions around deploying and managing
  TollGates")

The net4sats profile declares NIP-05 `_@net4sats.cash`, but
`https://net4sats.cash/.well-known/nostr.json` returns **404**, so that identifier is
currently unverifiable — which is why the page cites only the npub and not the address.

Either way the page must keep the **"Built on TollGate"** footer: attribution is a
licence obligation (GPL-3.0), and `tests/shell/test-licence-attribution.sh` asserts the
wording used elsewhere so all three surfaces agree.
