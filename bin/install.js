#!/usr/bin/env node

const { spawn } = require("child_process");
const path = require("path");

const SCRIPT_DIR = path.join(__dirname, "..");
const INSTALL_SCRIPT = path.join(SCRIPT_DIR, "install.sh");

// Handle --uninstall flag
const args = process.argv.slice(2);
const isUninstall = args.includes("--uninstall") || args.includes("uninstall");

// Check if running interactively (npx) or as postinstall
const isPostInstall = process.env.npm_lifecycle_event === "postinstall";

if (isPostInstall) {
  // During npm install, just ensure the script is available
  console.log("\nClaude Code Statusline installed.");
  console.log("Run 'npx claude-code-statusline' to configure.\n");
  process.exit(0);
}

// Run the interactive installer
const installArgs = isUninstall ? ["--uninstall"] : [];
const child = spawn("bash", [INSTALL_SCRIPT, ...installArgs], {
  stdio: "inherit",
  cwd: SCRIPT_DIR,
});

child.on("exit", (code) => {
  process.exit(code || 0);
});
