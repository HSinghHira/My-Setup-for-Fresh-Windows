# ── Extensions installed and ENABLED ─────────────────────────────────────
    $script:enabledExtensions = @(
        'xyz.local-history',                       # Local file history
        'mrmlnc.vscode-csscomb',                   # CSS property sorter
        'PKief.material-icon-theme',               # Material file icons
        'maciejdems.add-to-gitignore',             # Add to .gitignore from explorer
        'astro-build.astro-vscode',                # Astro framework support
        'formulahendry.auto-close-tag',            # Auto close HTML/XML tags
        'steoates.autoimport',                     # Auto import suggestions
        'NuclleaR.vscode-extension-auto-import',  # Auto import for JS/TS
        'formulahendry.auto-rename-tag',           # Auto rename paired tags
        'oleksandr.beatify-ejs',                   # EJS beautifier
        'michelemelluso.code-beautifier',          # Code beautifier
        'aaron-bond.better-comments',             # Colour-coded comment annotations
        'anseki.vscode-color',                     # Inline colour picker
        'BrainstormDevelopment.copy-project-tree',# Copy folder tree to clipboard
        'pranaygp.vscode-css-peek',               # Peek CSS from HTML
        'easy-snippet-maker.custom-snippet-maker',# Create custom snippets
        'usernamehw.errorlens',                   # Inline error display
        'rslfrkndmrky.rsl-vsc-focused-folder',    # Focus single folder in explorer
        'vincaslt.highlight-matching-tag',        # Highlight matching HTML tags
        'hwencc.html-tag-wrapper',                # Wrap selection in HTML tag
        'bradgashler.htmltagwrap',                # Wrap selection in HTML tag (alt)
        'kisstkondoros.vscode-gutter-preview',    # Image preview in gutter
        'DutchIgor.json-viewer',                  # JSON tree viewer
        'ms-vscode.live-server',                  # Microsoft Live Preview
        'ritwickdey.LiveServer',                  # Ritwick's Live Server
        'zaaack.markdown-editor',                 # WYSIWYG markdown editor
        'unifiedjs.vscode-mdx',                   # MDX language support
        'josee9988.minifyall',                    # Minify JS/CSS/HTML
        'mrkou47.npmignore',                      # .npmignore support
        'ionutvmi.path-autocomplete',             # Path autocomplete
        'christian-kohler.path-intellisense',     # Path intellisense
        'johnpapa.vscode-peacock',                # Colour-code workspace windows
        'esbenp.prettier-vscode',                 # Prettier formatter
        'sototecnologia.remove-comments-frontend',# Remove frontend comments
        'misbahansori.svg-fold',                  # Fold SVG elements
        'vdanchenkov.tailwind-class-sorter',      # Sort Tailwind classes
        'sidharthachatterjee.vscode-tailwindcss', # Tailwind CSS (alt)
        'bradlc.vscode-tailwindcss',              # Official Tailwind IntelliSense
        'esdete.tailwind-rainbow',                # Colour Tailwind classes
        'bourhaouta.tailwindshades',              # Generate Tailwind shades
        'dejmedus.tailwind-sorter',               # Sort Tailwind classes (alt)
        'meganrogge.template-string-converter',   # Convert to template literals
        'shardulm94.trailing-spaces',             # Highlight trailing spaces
        'Phu1237.vs-browser',                     # In-editor browser
        'westenets.vscode-backup',                # Settings & extension backup
        'MarkosTh09.color-picker',                # Colour picker widget
        'redhat.vscode-yaml',                     # YAML language support
        'streetsidesoftware.code-spell-checker'   # Spell checker
    )

    # ── Extensions installed but started DISABLED ─────────────────────────────
    $script:disabledExtensions = @(
        'tamasfe.even-better-toml',   # TOML language support
        'DavidKol.fastcompare',       # Fast file comparison
        'Nobuwu.mc-color',            # Minecraft colour codes
        'Misodee.vscode-nbt',         # Minecraft NBT file support
        'WebCrafter.auto-type-code',  # Auto type code snippets
        'adpyke.codesnap',            # Code screenshot tool
        'WebNative.webnative'         # WebNative framework support
    )

    # NOTE: $vscodeOnlyExtensions has been removed.
    # All extensions are now downloaded as VSIX and installed into every IDE,
    # so Marketplace availability is no longer a limiting factor.