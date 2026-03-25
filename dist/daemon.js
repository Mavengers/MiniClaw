import { ContextKernel } from "./kernel.js";
/**
 * MiniClaw Daemon
 * This process runs the autonomic system (heartbeats, sensing, metabolism)
 * independently of any MCP connection.
 */
async function main() {
    console.error("[MiniClaw] Daemon awakening...");
    const kernel = new ContextKernel();
    // Initialize the kernel with default workspace info
    // (In daemon mode, it primarily watches the current directory)
    await kernel.loadEpigenetics({
        path: process.cwd(),
        name: "autonomic-field",
        git: { isRepo: false },
        techStack: []
    });
    // Start the background autonomic processes
    kernel.startAutonomic();
    console.error("[MiniClaw] Daemon is now breathing in the background.");
    // Keep alive
    process.on('SIGINT', () => {
        console.error("[MiniClaw] Daemon sighing and going to sleep...");
        process.exit(0);
    });
}
main().catch(err => {
    console.error(`[MiniClaw] Daemon fatal error: ${err}`);
    process.exit(1);
});
