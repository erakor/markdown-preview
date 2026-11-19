import base from '@erakor/toolchain/oxfmt'

const config = { ...base, ignorePatterns: ['src/vendor/**', 'pnpm-lock.yaml'] }

export default config
