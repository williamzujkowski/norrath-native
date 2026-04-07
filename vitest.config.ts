import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: false,
    environment: "node",
    include: ["tests/**/*.test.ts"],
    coverage: {
      provider: "v8",
      include: ["src/**/*.ts"],
      exclude: [
        "src/types/**",
        "src/cli.ts", // Entry point — tested via integration tests, not unit tests
      ],
      thresholds: {
        statements: 80,
        branches: 60, // Some branches are defensive guards that rarely execute
        functions: 80,
        lines: 80,
      },
    },
  },
});
