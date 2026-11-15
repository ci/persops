import type { Register, ThemeSetArgs } from 'claude-code'

import { makeColors } from './make-colors.js'

// Catppuccin palettes (https://catppuccin.com/palette), matching the Mocha
// setup used across persops (ghostty, nvim, tmux, starship, fish, yazi).
const mocha = {
  rosewater: '#f5e0dc',
  flamingo: '#f2cdcd',
  pink: '#f5c2e7',
  mauve: '#cba6f7',
  red: '#f38ba8',
  maroon: '#eba0ac',
  peach: '#fab387',
  yellow: '#f9e2af',
  green: '#a6e3a1',
  teal: '#94e2d5',
  sky: '#89dceb',
  sapphire: '#74c7ec',
  blue: '#89b4fa',
  lavender: '#b4befe',
  text: '#cdd6f4',
  subtext1: '#bac2de',
  subtext0: '#a6adc8',
  overlay2: '#9399b2',
  overlay1: '#7f849c',
  overlay0: '#6c7086',
  surface2: '#585b70',
  surface1: '#45475a',
  surface0: '#313244',
  base: '#1e1e2e',
  mantle: '#181825',
  crust: '#11111b',
} as const

const latte = {
  rosewater: '#dc8a78',
  flamingo: '#dd7878',
  pink: '#ea76cb',
  mauve: '#8839ef',
  red: '#d20f39',
  maroon: '#e64553',
  peach: '#fe640b',
  yellow: '#df8e1d',
  green: '#40a02b',
  teal: '#179299',
  sky: '#04a5e5',
  sapphire: '#209fb5',
  blue: '#1e66f5',
  lavender: '#7287fd',
  text: '#4c4f69',
  subtext1: '#5c5f77',
  subtext0: '#6c6f85',
  overlay2: '#7c7f93',
  overlay1: '#8c8fa1',
  overlay0: '#9ca0b0',
  surface2: '#acb0be',
  surface1: '#bcc0cc',
  surface0: '#ccd0da',
  base: '#eff1f5',
  mantle: '#e6e9ef',
  crust: '#dce0e8',
} as const

// Catppuccin: Mocha after dark, Latte by day, mauve as the accent.
// Roles map onto Catppuccin's own syntax colors where the app allows:
// keywords mauve, strings green, literals peach, names red, variables yellow.
const { theme, problems } = makeColors({
  id: 'catppuccin',
  label: 'Catppuccin',
  codeTheme: { light: 'catppuccin-latte', dark: 'catppuccin-mocha' },
  light: {
    gray: {
      anchors: {
        'surface-0': latte.base,
        'surface-1': '#f4f5f8',
        'surface-2': '#f9fafb',
        'text-primary': latte.text,
        'text-secondary': latte.subtext1,
        'text-muted': latte.subtext0,
      },
    },
    roles: {
      accent: latte.mauve,
      danger: latte.red,
      success: latte.green,
      warning: latte.yellow,
      pro: latte.peach,
    },
    git: {
      added: latte.green,
      removed: latte.red,
      modified: latte.blue,
      merged: latte.mauve,
      closed: latte.maroon,
      conflicting: latte.peach,
      draft: latte.overlay1,
    },
  },
  dark: {
    gray: {
      anchors: {
        'surface-0': mocha.base,
        'surface-1': '#242436',
        'surface-2': '#2a2b3d',
        'surface-3': mocha.surface0,
        'text-primary': mocha.text,
        'text-secondary': mocha.subtext1,
        'text-muted': mocha.subtext0,
      },
    },
    roles: {
      accent: mocha.mauve,
      danger: mocha.red,
      success: mocha.green,
      warning: mocha.yellow,
      pro: mocha.peach,
    },
    git: {
      added: mocha.green,
      removed: mocha.red,
      modified: mocha.blue,
      merged: mocha.mauve,
      closed: mocha.maroon,
      conflicting: mocha.peach,
      draft: mocha.overlay1,
    },
  },
})

const LOOK: ThemeSetArgs = { colors: theme }

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    const unpainted = problems.find(line => line.startsWith("Desktop won't paint"))

    if (unpainted !== undefined) {
      $.ui.toast(unpainted)
    }

    await $.theme.set(LOOK)

    return next(e)
  })
}
