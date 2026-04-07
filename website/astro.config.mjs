// @ts-check
import { defineConfig } from 'astro/config';
import svelte from '@astrojs/svelte';
import mdx from '@astrojs/mdx';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  site: 'https://williamzujkowski.github.io',
  base: '/norrath-native',
  integrations: [svelte(), mdx()],
  vite: {
    plugins: [tailwindcss()],
  },
});
