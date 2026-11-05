.pragma library

// Danh sách app chọn sẵn cho Cửa hàng Islet (tên gói trong kho Arch).
//   aur: lấy từ AUR (cộng đồng đóng gói, build trên máy) · pkgs trong bộ có thể ghi "aur/<tên>"
//   cli: app chạy trong terminal ("Mở" = mở kitty chạy lệnh) · tool: thư viện / công cụ, không có nút Mở
var categories = [
    { id: "internet", label: "Internet",       icon: "globe", from: "#3B8BFF", to: "#2EE6D6" },
    { id: "media",    label: "Music & Video",   icon: "music", from: "#FF5C7A", to: "#FF9F43" },
    { id: "graphics", label: "Graphics",         icon: "palette", from: "#B65CFF", to: "#FF6FB5" },
    { id: "office",   label: "Office",      icon: "document", from: "#34D399", to: "#10B9C9" },
    { id: "stacks",   label: "Dev Stacks",   icon: "layers", from: "#4BE3E8", to: "#6D4AFF" },
    { id: "ai",       label: "AI & Agent",     icon: "sparkle", from: "#FF6FB5", to: "#8B5CFF" },
    { id: "dev",      label: "Developer",      icon: "code", from: "#6D4AFF", to: "#4BE3E8" },
    { id: "games",    label: "Games",       icon: "gamepad", from: "#FFB15C", to: "#FF5C8A" },
    { id: "tools",    label: "Utilities",       icon: "toolbox", from: "#7A8396", to: "#3B4253" }
];

var apps = [
    // Internet
    { pkg: "chromium",          name: "Chromium",          cat: "internet", desc: "Fast, lightweight open-source base of Google Chrome" },
    { pkg: "thunderbird",       name: "Thunderbird",       cat: "internet", desc: "Email, calendar and contacts" },
    { pkg: "telegram-desktop",  name: "Telegram",          cat: "internet", desc: "Fast, secure messaging synced across devices" },
    { pkg: "discord",           name: "Discord",           cat: "internet", desc: "Voice, video and community chat" },
    { pkg: "qbittorrent",       name: "qBittorrent",       cat: "internet", desc: "Lightweight, ad-free torrent client" },
    { pkg: "filezilla",         name: "FileZilla",         cat: "internet", desc: "Transfer files over FTP / SFTP" },

    // Nhạc & Video
    { pkg: "vlc",               name: "VLC",               cat: "media", desc: "Plays every audio and video format", featured: true },
    { pkg: "spotify-launcher",  name: "Spotify",           cat: "media", desc: "Stream millions of songs", featured: true },
    { pkg: "audacious",         name: "Audacious",         cat: "media", desc: "Lightweight music player with a clean UI" },
    { pkg: "obs-studio",        name: "OBS Studio",        cat: "media", desc: "Screen recording and live streaming", featured: true },
    { pkg: "kdenlive",          name: "Kdenlive",          cat: "media", desc: "Professional multi-track video editing" },
    { pkg: "shotcut",           name: "Shotcut",           cat: "media", desc: "Simple, easy-to-learn video editor" },
    { pkg: "handbrake",         name: "HandBrake",         cat: "media", desc: "Convert and compress video" },

    // Đồ hoạ
    { pkg: "gimp",              name: "GIMP",              cat: "graphics", desc: "Powerful image editor, a Photoshop alternative", featured: true },
    { pkg: "inkscape",          name: "Inkscape",          cat: "graphics", desc: "Vector drawing, logos and illustration" },
    { pkg: "krita",             name: "Krita",             cat: "graphics", desc: "Digital painting for artists" },
    { pkg: "blender",           name: "Blender",           cat: "graphics", desc: "3D modeling, animation and VFX", featured: true },
    { pkg: "darktable",         name: "darktable",         cat: "graphics", desc: "RAW photo processing for photographers" },
    { pkg: "loupe",             name: "Loupe",             cat: "graphics", desc: "Fast, beautiful image viewer" },

    // Văn phòng
    { pkg: "libreoffice-fresh", name: "LibreOffice",       cat: "office", desc: "Documents, spreadsheets and presentations (like Office)", featured: true },
    { pkg: "papers",            name: "Papers",            cat: "office", desc: "Read PDF documents" },
    { pkg: "obsidian",          name: "Obsidian",          cat: "office", desc: "Take notes and organize ideas in Markdown" },
    { pkg: "xournalpp",         name: "Xournal++",         cat: "office", desc: "Handwriting and PDF annotation" },
    { pkg: "gnome-calculator",  name: "Calculator",          cat: "office", desc: "Basic and scientific calculator" },
    { pkg: "gnome-text-editor", name: "Text Editor", cat: "office", desc: "Notes and simple text editing" },

    // AI & Agent
    { pkg: "antigravity",  name: "Antigravity",   cat: "ai", aur: true, featured: true, desc: "Google's agentic IDE — hand off a task, agents write, run and test the code" },
    { pkg: "cursor-bin",   name: "Cursor",        cat: "ai", aur: true, featured: true, desc: "AI code editor built on VS Code, with Agent and smart Tab" },
    { pkg: "claude-code",  name: "Claude Code",   cat: "ai", aur: true, cli: "claude", desc: "Anthropic's coding agent, right in your terminal" },
    { pkg: "gemini-cli",   name: "Gemini CLI",    cat: "ai", cli: "gemini", desc: "Google's AI agent in your terminal, generous free tier" },
    { pkg: "openai-codex", name: "Codex CLI",     cat: "ai", cli: "codex", desc: "OpenAI's coding agent that runs on your machine" },
    { pkg: "opencode",     name: "OpenCode",      cat: "ai", cli: "opencode", desc: "Open-source coding agent for many models (Claude, GPT, Gemini, local)" },
    { pkg: "ollama",       name: "Ollama",        cat: "ai", cli: "ollama list; echo; echo 'Try: ollama run gemma3'; exec bash", desc: "Run AI models locally, no internet needed (Llama, Gemma, Qwen…)" },
    { pkg: "lmstudio-bin", name: "LM Studio",     cat: "ai", aur: true, desc: "Download and chat with offline AI models, beautifully" },

    // Lập trình
    // Bộ lập trình: cài một lần cả bộ công cụ (icon: shell/assets/apps/<icon>.svg)
    { pkg: "stack:ai",     name: "AI Agent · Terminal", cat: "stacks", icon: "stack-ai", featured: true, pkgs: ["aur/claude-code", "gemini-cli", "openai-codex", "opencode"], desc: "Claude Code, Gemini CLI, Codex CLI, OpenCode — coding assistants in your terminal" },
    { pkg: "stack:web",    name: "Web · JavaScript",  cat: "stacks", icon: "stack-web",    featured: true, pkgs: ["nodejs", "npm", "pnpm", "yarn", "bun", "deno"], desc: "Node.js, npm, pnpm, Yarn, Bun, Deno" },
    { pkg: "stack:python", name: "Python",            cat: "stacks", icon: "stack-python", featured: true, pkgs: ["python", "python-pip", "python-pipx", "uv", "python-virtualenv"], desc: "Python 3, pip, pipx, uv, virtualenv" },
    { pkg: "stack:cpp",    name: "C / C++",           cat: "stacks", icon: "stack-cpp",    pkgs: ["base-devel", "gcc", "clang", "cmake", "ninja", "meson", "gdb", "lldb"], desc: "GCC, Clang, CMake, Ninja, Meson, GDB, LLDB" },
    { pkg: "stack:rust",   name: "Rust",              cat: "stacks", icon: "stack-rust",   pkgs: ["rustup"], desc: "rustup + the stable toolchain (cargo, rustc, clippy)" },
    { pkg: "stack:go",     name: "Go",                cat: "stacks", icon: "stack-go",     pkgs: ["go", "gopls"], desc: "Go and gopls for your editor" },
    { pkg: "stack:java",   name: "Java",              cat: "stacks", icon: "stack-java",   pkgs: ["jdk-openjdk", "maven", "gradle"], desc: "OpenJDK, Maven, Gradle" },
    { pkg: "stack:docker", name: "Docker",            cat: "stacks", icon: "stack-docker", featured: true, pkgs: ["docker", "docker-compose", "docker-buildx"], desc: "Docker, Compose, Buildx — service and permissions set up for you" },
    { pkg: "stack:git",    name: "Git & GitHub",      cat: "stacks", icon: "stack-git",    pkgs: ["git", "github-cli", "lazygit", "git-delta"], desc: "Git, GitHub CLI (gh), lazygit, delta" },
    { pkg: "stack:php",    name: "PHP",               cat: "stacks", icon: "stack-php",    pkgs: ["php", "composer"], desc: "PHP and Composer" },
    { pkg: "stack:dotnet", name: ".NET",              cat: "stacks", icon: "stack-dotnet", pkgs: ["dotnet-sdk"], desc: ".NET SDK (C#, F#)" },

    // Lập trình: trình soạn code / IDE
    { pkg: "visual-studio-code-bin", name: "Visual Studio Code", cat: "dev", aur: true, featured: true, desc: "Microsoft's official VS Code — with Marketplace, Copilot and Remote SSH" },
    { pkg: "code",              name: "Code - OSS",        cat: "dev", desc: "Code editor (open-source build of VS Code)", featured: true },
    { pkg: "zed",               name: "Zed",               cat: "dev", desc: "Blazing-fast editor with AI and multiplayer coding" },
    { pkg: "pycharm-community-edition", name: "PyCharm Community", cat: "dev", desc: "JetBrains' Python IDE" },
    { pkg: "qtcreator",         name: "Qt Creator",        cat: "dev", desc: "IDE for C++ and Qt / QML" },
    { pkg: "kdevelop",          name: "KDevelop",          cat: "dev", desc: "IDE cho C, C++, Python, PHP" },
    { pkg: "gnome-builder",     name: "Builder",           cat: "dev", desc: "IDE for building GNOME / GTK apps" },
    { pkg: "lapce",             name: "Lapce",             cat: "dev", desc: "Lightweight, fast editor written in Rust" },
    { pkg: "kate",              name: "Kate",              cat: "dev", desc: "Powerful editor with LSP and a terminal" },
    { pkg: "geany",             name: "Geany",             cat: "dev", desc: "Lightweight IDE that starts instantly" },
    { pkg: "emacs",             name: "Emacs",             cat: "dev", desc: "The infinitely extensible editor" },
    { pkg: "gvim",              name: "GVim",              cat: "dev", desc: "Vim with a graphical interface" },
    { pkg: "neovim",            name: "Neovim",            cat: "dev", desc: "Terminal-based editor", cli: "nvim" },
    { pkg: "helix",             name: "Helix",             cat: "dev", desc: "Modal editor with built-in LSP", cli: "helix" },
    { pkg: "jupyterlab",        name: "JupyterLab",        cat: "dev", desc: "Python notebooks for data and machine learning" },
    { pkg: "spyder",            name: "Spyder",            cat: "dev", desc: "Python IDE for data science" },
    { pkg: "godot",             name: "Godot",             cat: "dev", desc: "Make 2D / 3D games" },
    // Git, so sánh tệp
    { pkg: "gitg",              name: "gitg",              cat: "dev", desc: "Visual Git history" },
    { pkg: "qgit",              name: "QGit",              cat: "dev", desc: "Browse Git repositories visually" },
    { pkg: "meld",              name: "Meld",              cat: "dev", desc: "Compare and merge files and folders" },
    { pkg: "kompare",           name: "Kompare",           cat: "dev", desc: "See the differences between two files" },
    // Cơ sở dữ liệu
    { pkg: "dbeaver",           name: "DBeaver",           cat: "dev", desc: "Manage MySQL, PostgreSQL, SQLite…" },
    { pkg: "sqlitebrowser",     name: "DB Browser for SQLite", cat: "dev", desc: "Open and edit SQLite files" },
    // Container, máy ảo, mạng
    { pkg: "podman-desktop",    name: "Podman Desktop",    cat: "dev", desc: "Manage containers visually" },
    { pkg: "virt-manager",      name: "Virtual Machine Manager", cat: "dev", desc: "Create and run KVM virtual machines" },
    { pkg: "wireshark-qt",      name: "Wireshark",         cat: "dev", desc: "Network packet analyzer" },
    // Gỡ lỗi, đo hiệu năng
    { pkg: "heaptrack",         name: "Heaptrack",         cat: "dev", desc: "Find memory leaks" },
    { pkg: "kcachegrind",       name: "KCachegrind",       cat: "dev", desc: "Visualize profiling data (callgrind)" },
    { pkg: "sysprof",           name: "Sysprof",           cat: "dev", desc: "System-wide profiler" },
    { pkg: "d-spy",             name: "D-Spy",             cat: "dev", desc: "Inspect and call D-Bus" },
    { pkg: "ghex",              name: "GHex",              cat: "dev", desc: "View and edit binary files (hex)" },
    { pkg: "okteta",            name: "Okteta",            cat: "dev", desc: "Advanced hex editor" },
    // Terminal
    { pkg: "ghostty",           name: "Ghostty",           cat: "dev", desc: "Fast, GPU-accelerated terminal" },
    { pkg: "wezterm",           name: "WezTerm",           cat: "dev", desc: "Terminal with split panes, configured in Lua" },
    { pkg: "alacritty",         name: "Alacritty",         cat: "dev", desc: "Minimal and very fast terminal" },
    // Khác
    { pkg: "drawio-desktop",    name: "draw.io",           cat: "dev", desc: "Diagrams, UML and system architecture" },
    { pkg: "kicad",             name: "KiCad",             cat: "dev", desc: "Electronics and PCB design" },
    { pkg: "octave",            name: "GNU Octave",        cat: "dev", desc: "Numerical computing (like MATLAB)" },
    { pkg: "devhelp",           name: "Devhelp",           cat: "dev", desc: "Read API docs offline" },

    // Trò chơi
    { pkg: "supertuxkart",      name: "SuperTuxKart",      cat: "games", desc: "Fun kart racing with friends", featured: true },
    { pkg: "luanti",            name: "Luanti",            cat: "games", desc: "Block-building sandbox (like Minecraft)" },
    { pkg: "0ad",               name: "0 A.D.",            cat: "games", desc: "Real-time strategy in ancient times" },
    { pkg: "xonotic",           name: "Xonotic",           cat: "games", desc: "Fast-paced first-person shooter" },
    { pkg: "gnome-chess",       name: "Chess",            cat: "games", desc: "Play chess against the computer or friends" },

    // Tiện ích
    { pkg: "gnome-disk-utility",   name: "Disk",          cat: "tools", desc: "Manage and format disks and USB drives" },
    { pkg: "baobab",               name: "Disk Usage Analyzer", cat: "tools", desc: "See which folders take up space" },
    { pkg: "file-roller",          name: "Archive manager", cat: "tools", desc: "Open zip, rar, 7z and tar files" },
    { pkg: "gnome-system-monitor", name: "System Monitor", cat: "tools", desc: "View processes and resources" },
    { pkg: "bleachbit",            name: "BleachBit",      cat: "tools", desc: "Clean up junk and free disk space" },
    { pkg: "gnome-weather",        name: "Weather",      cat: "tools", desc: "Weather forecasts for your city" },
    { pkg: "gnome-clocks",         name: "Clock",        cat: "tools", desc: "Alarms, timers and world clocks" },
    { pkg: "htop",                 name: "htop",           cat: "tools", desc: "View processes in the terminal", cli: "htop" },
];

function category(id) {
    for (var i = 0; i < categories.length; i++) if (categories[i].id === id) return categories[i];
    return categories[categories.length - 1];
}
function byPkg(pkg) {
    for (var i = 0; i < apps.length; i++) if (apps[i].pkg === pkg) return apps[i];
    return null;
}
